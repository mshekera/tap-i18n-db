Fiber = Npm.require 'fibers'

share.i18nCollectionExtensions = (obj) ->
  obj.i18nFind = (selector, options) ->
    current_language = Fiber.current.language_tag

    if _.isUndefined current_language
      throw new Meteor.Error 500, 'TAPi18n.i18nFind should be called only from TAPi18n.publish functions'

    if _.isUndefined selector then selector = {}

    supported_languages = TAPi18n.conf.supported_languages

    if current_language? and not (current_language in supported_languages)
      throw new Meteor.Error 400, 'Not supported language'

    unless options? then options = {}

    return @find selector, _.extend {}, options, {fields: options.fields or {}}

  return obj

TAPi18n.publish = (name, handler, options) ->
  if name is null
    throw new Meteor.Error 500, 'TAPi18n.publish doesn\'t support null publications'

  i18n_handler = () ->
    args = Array.prototype.slice.call arguments

    # last subscription argument is always the language tag
    language_tag = _.last args
    @language = language_tag
    # Set handler context in current fiber's
    Fiber.current.language_tag = language_tag
    # Call the user handler without the language_tag argument
    cursors = handler.apply this, args.slice 0, -1
    # Clear handler context
    delete Fiber.current.language_tag

    if cursors?
      return cursors

  # set the actual publish method
  return Meteor.publish name, i18n_handler, options

TAPi18n.publishComposite = (name, options) ->
  if name is null
    throw new Meteor.Error 500, 'TAPi18n.publishComposite doesn\'t support null publications'

  i18n_handler = () ->
    args = Array.prototype.slice.call(arguments)

    # last subscription argument is always the language tag
    language_tag = _.last(args)
    @language = language_tag
    # Set handler context in current fiber's
    Fiber.current.language_tag = language_tag
    # Call the user handler without the language_tag argument
    if _.isFunction options
      handler = options.apply this, args.slice 0, -1
    else
      handler = options
    # Clear handler context
    delete Fiber.current.language_tag

    return handler

  # set the actual publish method
  return Meteor.publishComposite name, i18n_handler
