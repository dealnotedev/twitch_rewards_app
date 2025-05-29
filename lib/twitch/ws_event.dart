class WsMessage {
  final WsMessagePayload payload;

  WsMessage({required this.payload});

  static WsMessage fromJson(dynamic json) {
    return WsMessage(payload: WsMessagePayload.fromJson(json['payload']));
  }
}

class WsMessagePayload {
  final WsMessageSubscription? subscription;
  final WsMessageEvent? event;

  WsMessagePayload({required this.subscription, required this.event});

  static WsMessagePayload fromJson(dynamic json) {
    final eventJson = json['event'];
    final subsJson = json['subscription'];

    return WsMessagePayload(
      subscription:
          subsJson != null ? WsMessageSubscription.fromJson(subsJson) : null,
      event: eventJson != null ? WsMessageEvent.fromJson(eventJson) : null,
    );
  }
}

class WsReward {
  final String title;
  final int cost;

  WsReward({required this.title, required this.cost});

  static WsReward fromJson(dynamic json) {
    return WsReward(title: json['title'] as String, cost: json['cost'] as int);
  }
}

class WsMessageEvent {
  final String? id;
  final String? userName;
  final String? userId;

  final WsReward? reward;
  final WsChatMessage? message;

  final String? chatterUserName;
  final String? chatterUserId;

  /*Example: text, power_ups_gigantified_emote, power_ups_message_effect, channel_points_highlighted*/
  final String? messageType;

  final String? messageId;
  final String? color;

  WsMessageEvent({
    required this.id,
    required this.userName,
    required this.userId,
    required this.reward,
    required this.message,
    required this.messageType,
    required this.chatterUserId,
    required this.chatterUserName,
    required this.messageId,
    required this.color
  });

  static WsMessageEvent fromJson(dynamic json) {
    final rewardJson = json['reward'];
    final messageJson = json['message'];
    return WsMessageEvent(
      id: json['id'] as String?,
      userName: json['user_name'] as String?,
      userId: json['user_id'] as String?,
      message: messageJson != null ? WsChatMessage.fromJson(messageJson) : null,
      reward: rewardJson != null ? WsReward.fromJson(rewardJson) : null,
      messageType: json['message_type'] as String?,
        chatterUserId: json['chatter_user_id'] as String?,
        chatterUserName: json['chatter_user_name'] as String?,
        messageId: json['message_id'] as String?,
        color: json['color'] as String?
    );
  }
}

class WsMessageSubscription {
  final String type;

  WsMessageSubscription({required this.type});

  static WsMessageSubscription fromJson(dynamic json) {
    return WsMessageSubscription(type: json['type'] as String);
  }
}

class WsChatMessage {
  final String? text;
  final List<WsChatMessageFragment> fragments;

  WsChatMessage({required this.text, required this.fragments});

  static WsChatMessage fromJson(dynamic json) {
    return WsChatMessage(
      text: json['text'] as String?,
      fragments:
          ((json['fragments'] as List<dynamic>? ?? []).map(
            WsChatMessageFragment.fromJson,
          )).toList(),
    );
  }
}

enum WsFragmentType {
  mention,
  text,
  emote,
  unknown;

  static WsFragmentType fromString(String type) {
    for (var e in WsFragmentType.values) {
      if (type == e.name) {
        return e;
      }
    }
    return unknown;
  }
}

class WsChatMessageFragment {
  final WsFragmentType type;
  final String? text;
  final WsChatEmote? emote;

  WsChatMessageFragment({
    required this.type,
    required this.text,
    required this.emote,
  });

  static WsChatMessageFragment fromJson(dynamic json) {
    final emoteJson = json['emote'];
    return WsChatMessageFragment(
      type: WsFragmentType.fromString(json['type'] as String),
      text: json['text'] as String?,
      emote: emoteJson != null ? WsChatEmote.fromJson(emoteJson) : null,
    );
  }
}

class WsChatEmote {
  final String id;
  final List<String> format;

  WsChatEmote({required this.id, required this.format});

  static WsChatEmote fromJson(dynamic json) {
    return WsChatEmote(
      id: json['id'] as String,
      format:
          (json['format'] as List<dynamic>).map((e) => e.toString()).toList(),
    );
  }
}
