removeTrailingUndefs = share.helpers.removeTrailingUndefs
extend = $.extend

traverseObject = (obj, language, collection_base_language) ->
  for key, val of obj
    if _.isObject val
      if fieldVal = val[language] or val[collection_base_language]
        obj[key] = fieldVal
      else
        traverseObject val, language, collection_base_language

share.i18nCollectionTransform = (doc, collection) ->
  for route in collection._disabledOnRoutes
    if route.test window.location.pathname
      return doc

  collection_base_language = collection._base_language
  language = TAPi18n.getLanguage()

  unless language? then return doc

  dialect_of = share.helpers.dialectOf language

  doc = _.clone doc, true # protect original object

  traverseObject doc, dialect_of or language, collection_base_language

  return doc

share.i18nCollectionExtensions = (obj) ->
  original =
    find: obj.find
    findOne: obj.findOne

  local_session = new ReactiveDict()
  for method of original
    do (method) ->
      obj[method] = (selector, options) ->
        local_session.get 'force_lang_switch_reactivity_hook'

        original[method].apply obj, removeTrailingUndefs [selector, options]

  obj.forceLangSwitchReactivity = _.once ->
    Deps.autorun () ->
      local_session.set 'force_lang_switch_reactivity_hook',
        TAPi18n.getLanguage()

    return

  obj._disabledOnRoutes = []
  obj._disableTransformationOnRoute = (route) ->
    obj._disabledOnRoutes.push route

  if Package.autopublish?
    obj.forceLangSwitchReactivity()

  return obj

TAPi18n.subscribe = (name) ->
  local_session = new ReactiveDict
  local_session.set 'ready', false

  # parse arguments
  params = Array.prototype.slice.call arguments, 1
  callbacks = {}
  if params.length
    lastParam = _.last params
    if typeof lastParam is 'function'
      callbacks.onReady = params.pop()
    else if lastParam and (typeof lastParam.onReady == 'function' or
                             typeof lastParam.onError == 'function')
      callbacks = params.pop()

  # We want the onReady/onError methods to be called
  # only once (not for every language change)
  onReadyCalled = false
  onErrorCalled = false
  original_onReady = callbacks.onReady
  callbacks.onReady = ->
    if onErrorCalled
      return

    local_session.set 'ready', true

    original_onReady?()

  if callbacks.onError?
    callbacks.onError = ->
      if onReadyCalled
        _.once callbacks.onError

  subscription = null
  subscription_computation = null
  subscribe = ->
    # subscription_computation, depends on TAPi18n.getLanguage(), to
    # resubscribe once the language gets changed.
    subscription_computation = Deps.autorun () ->
      lang_tag = TAPi18n.getLanguage()

      subscription =
        Meteor.subscribe.apply @,
          removeTrailingUndefs [].concat name, params, lang_tag, callbacks

      # if the subscription is already ready:
      local_session.set 'ready', subscription.ready()

  # If TAPi18n is called in a computation, to maintain Meteor.subscribe
  # behavior (which never gets invalidated), we don't want the computation to
  # get invalidated when TAPi18n.getLanguage get invalidated (when language get
  # changed).
  current_computation = Deps.currentComputation
  if currentComputation?
    # If TAPi18n.subscribe was called in a computation, call subscribe in a
    # non-reactive context, but make sure that if the computation is getting
    # invalidated also the subscription computation
    # (invalidations are allowed up->bottom but not bottom->up)
    Deps.onInvalidate ->
      subscription_computation.invalidate()

    Deps.nonreactive () ->
      subscribe()
  else
    # If there is no computation
    subscribe()

  return {
    ready: () -> local_session.get 'ready'
    stop: () -> subscription_computation.stop()
    _getSubscription: -> subscription
  }
