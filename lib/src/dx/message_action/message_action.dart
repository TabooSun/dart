import 'package:logging/logging.dart';
import 'package:pubnub/src/core/core.dart';
import 'package:pubnub/src/dx/_utils/utils.dart';

import 'package:pubnub/src/dx/_endpoints/message_action.dart';

final _log = Logger('pubnub.dx.messageAction');

mixin MessageActionDx on Core {
  /// Fetches all message actions of a given [channel]
  /// starting from [from] to [to] time
  /// If [from] is not provided, the server uses the current time
  /// Providing no [to] or [limit] means there is "no limit" to the number of actions being requested
  /// These actions can represent receipts, reactions or custom actions for messages.
  ///
  /// Pagination can be controlled using start, end and limit parameters, where start > end.
  /// If start is not provided, the server uses the current time.
  ///
  /// Providing no end or limit means there is "no limit" to the number of actions being requested.
  /// In this event the server will try and retrieve all actions for the channel, going back in time forever.
  /// You can use [limit] parameter to limit the number of fetched message actions
  ///
  /// In some cases, due to internal limitations on the number of queries performed per request,
  /// the server will not be able to give the full range of actions requested.
  Future<FetchMessageActionsResult> fetchMessageActions(String channel,
      {Timetoken from,
      Timetoken to,
      int limit,
      Keyset keyset,
      String using}) async {
    keyset ??= super.keysets.get(using, defaultIfNameIsNull: true);

    Ensure(keyset).isNotNull('keyset');
    Ensure(channel).isNotEmpty('channel');

    var fetchMessageActionsResult = FetchMessageActionsResult()..actions = [];

    var loopResult;
    do {
      loopResult = await defaultFlow(
          log: _log,
          core: this,
          params: FetchMessageActionsParams(keyset, channel,
              start: from, end: to, limit: limit),
          serialize: (object, [_]) =>
              FetchMessageActionsResult.fromJson(object));

      fetchMessageActionsResult..actions.addAll(loopResult.actions);

      if (loopResult.moreActions != null) {
        var more = loopResult.moreActions as MoreAction;
        if (more != null) {
          from = Timetoken(int.parse(more.start));
          to = Timetoken(int.parse(more.end));
          limit = more.limit;
        }
      }
    } while (loopResult.moreActions != null);
    fetchMessageActionsResult..status = loopResult.status;
    return fetchMessageActionsResult;
  }

  /// This method allows user to post actions on a "parent message"
  /// by specifying the [keyset], [channel], and [timetoken] of the parent message.
  ///
  /// The server does not validate that the parent message exists at the time the action is posted.
  /// The server does, however, check that you have not already added this particular action to this message.
  /// In other words, for a given parent message (identified by [subkey], [channel], [timetoken]),
  ///  there is at most one unique (type, value) pair per uuid.
  ///
  /// Message action contains two properties : action[type] and action[value] and those should not be empty
  /// Empty [type] and/or [value] throws Ensure exception
  Future<AddMessageActionResult> addMessageAction(
      String type, String value, String channel, Timetoken messageTimetoken,
      {Keyset keyset, String using}) async {
    keyset ??= super.keysets.get(using, defaultIfNameIsNull: true);

    Ensure(keyset).isNotNull('keyset');
    Ensure(type).isNotEmpty('message action type');
    Ensure(value).isNotEmpty('message action value');
    Ensure(messageTimetoken).isNotNull('message timetoken');

    var payload = <String, String>{};
    payload['type'] = type;
    payload['value'] = value;
    var addMessageActionbody = await super.parser.encode(payload);

    var params = AddMessageActionParams(
        keyset, channel, messageTimetoken, addMessageActionbody);

    return defaultFlow<AddMessageActionParams, AddMessageActionResult>(
        log: _log,
        core: this,
        params: params,
        serialize: (object, [_]) => AddMessageActionResult.fromJson(object));
  }

  /// Allows users to remove their previously-posted message actions,
  /// by specifying the parent message, and the single timetoken of the action(s) they wish to delete.
  ///
  /// It is technically possible to delete more than one action here,
  /// if the same UUID posted different actions on the same parent message at the same time.
  ///
  /// If all goes well, the action(s) will be deleted from the database,
  /// and one or more "action remove event" messages will be published in realtime
  /// on the same channel as the parent message.
  Future<DeleteMessageActionResult> deleteMessageAction(
      String channel, Timetoken messageTimetoken, Timetoken actionTimetoken,
      {Keyset keyset, String using}) async {
    keyset ??= super.keysets.get(using, defaultIfNameIsNull: true);

    Ensure(keyset).isNotNull('keyset');
    Ensure(channel).isNotEmpty('channel');
    Ensure(messageTimetoken).isNotNull('message timetoken');
    Ensure(actionTimetoken).isNotNull('action timetoken');

    var params = DeleteMessageActionParams(
        keyset, channel, messageTimetoken, actionTimetoken);

    return defaultFlow<DeleteMessageActionParams, DeleteMessageActionResult>(
        log: _log,
        core: this,
        params: params,
        serialize: (object, [_]) => DeleteMessageActionResult.fromJson(object));
  }
}