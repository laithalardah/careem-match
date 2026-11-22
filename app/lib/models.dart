// API v2.1 models (exact field names, no renames).

enum RoomMode {
  food('food'),
  dineout('dineout');

  const RoomMode(this.wire);
  final String wire;

  static RoomMode parse(String? v) => v == 'dineout' ? RoomMode.dineout : RoomMode.food;
}

enum RoomStage {
  lobby('lobby'),
  settings('settings'),
  swiping('swiping'),
  dispute('dispute'),
  matching('matching'),
  result('result'),
  ordered('ordered');

  const RoomStage(this.wire);
  final String wire;

  static RoomStage parse(String? v) => RoomStage.values.firstWhere(
        (e) => e.wire == v,
        orElse: () => RoomStage.lobby,
      );
}

enum SwipeLevel {
  category('category'),
  restaurant('restaurant');

  const SwipeLevel(this.wire);
  final String wire;

  static SwipeLevel? parse(String? v) {
    if (v == 'category') return SwipeLevel.category;
    if (v == 'restaurant') return SwipeLevel.restaurant;
    return null;
  }
}

enum MealType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  dessert('dessert', 'Dessert');

  const MealType(this.wire, this.label);
  final String wire;
  final String label;

  static MealType? parse(String? v) {
    for (final m in MealType.values) {
      if (m.wire == v) return m;
    }
    return null;
  }
}

class HealthInfo {
  final String status;
  final bool demo;
  const HealthInfo({required this.status, required this.demo});

  factory HealthInfo.fromJson(Map<String, dynamic> j) => HealthInfo(
        status: (j['status'] ?? 'ok') as String,
        demo: j['demo'] == true,
      );
}

class CreateRoomResult {
  final String roomCode;
  final String participantId;
  final String joinUrl;
  const CreateRoomResult({required this.roomCode, required this.participantId, required this.joinUrl});

  factory CreateRoomResult.fromJson(Map<String, dynamic> j) => CreateRoomResult(
        roomCode: '${j['room_code']}',
        participantId: '${j['participant_id']}',
        joinUrl: (j['join_url'] ?? '') as String,
      );
}

class JoinRoomResult {
  final String participantId;
  const JoinRoomResult({required this.participantId});

  factory JoinRoomResult.fromJson(Map<String, dynamic> j) => JoinRoomResult(
        participantId: '${j['participant_id']}',
      );
}

class ParticipantProgress {
  final SwipeLevel? level;
  final int swiped;
  final int total;
  final bool done;

  const ParticipantProgress({this.level, this.swiped = 0, this.total = 0, this.done = false});

  factory ParticipantProgress.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ParticipantProgress();
    return ParticipantProgress(
      level: SwipeLevel.parse(j['level'] as String?),
      swiped: (j['swiped'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      done: j['done'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level?.wire,
        'swiped': swiped,
        'total': total,
        'done': done,
      };
}

class Participant {
  final String id;
  final String name;
  final bool isHost;
  final bool isBot;
  final ParticipantProgress progress;

  const Participant({
    required this.id,
    required this.name,
    required this.isHost,
    this.isBot = false,
    this.progress = const ParticipantProgress(),
  });

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
        id: '${j['id']}',
        name: (j['name'] ?? 'Guest') as String,
        isHost: j['is_host'] == true,
        isBot: j['is_bot'] == true,
        progress: ParticipantProgress.fromJson(j['progress'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_host': isHost,
        'is_bot': isBot,
        'progress': progress.toJson(),
      };
}

class RoomSettings {
  final MealType? meal;
  const RoomSettings({this.meal});

  factory RoomSettings.fromJson(Map<String, dynamic>? j) =>
      RoomSettings(meal: MealType.parse(j?['meal'] as String?));

  Map<String, dynamic> toJson() => {'meal': meal?.wire};
}

class DisputeContender {
  final int restaurantId;
  final String name;
  final String? imageUrl;
  final String cuisine;
  final List<String> supporterIds;

  const DisputeContender({
    required this.restaurantId,
    required this.name,
    this.imageUrl,
    this.cuisine = '',
    this.supporterIds = const [],
  });

  factory DisputeContender.fromJson(Map<String, dynamic> j) => DisputeContender(
        restaurantId: (j['restaurant_id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
        cuisine: (j['cuisine'] ?? '') as String,
        supporterIds: [for (final s in (j['supporter_ids'] ?? const []) as List) '$s'],
      );

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'name': name,
        'image_url': imageUrl,
        'cuisine': cuisine,
        'supporter_ids': supporterIds,
      };
}

class WheelSegment {
  final int restaurantId;
  final String name;
  final double weight;

  const WheelSegment({required this.restaurantId, required this.name, required this.weight});

  factory WheelSegment.fromJson(Map<String, dynamic> j) => WheelSegment(
        restaurantId: (j['restaurant_id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        weight: ((j['weight'] ?? 1) as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'name': name,
        'weight': weight,
      };
}

class WheelState {
  final List<WheelSegment> segments;
  final String? spinId;
  final int? spinStartedAtMs;
  final int durationMs;
  final double? finalAngleDeg;
  final int? winnerRestaurantId;

  const WheelState({
    required this.segments,
    this.spinId,
    this.spinStartedAtMs,
    this.durationMs = 4500,
    this.finalAngleDeg,
    this.winnerRestaurantId,
  });

  bool get hasSpun => spinId != null && finalAngleDeg != null;

  factory WheelState.fromJson(Map<String, dynamic> j) => WheelState(
        segments: [for (final s in (j['segments'] ?? const []) as List) WheelSegment.fromJson(s as Map<String, dynamic>)],
        spinId: j['spin_id'] as String?,
        spinStartedAtMs: (j['spin_started_at_ms'] as num?)?.toInt(),
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 4500,
        finalAngleDeg: (j['final_angle_deg'] as num?)?.toDouble(),
        winnerRestaurantId: (j['winner_restaurant_id'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'segments': [for (final s in segments) s.toJson()],
        'spin_id': spinId,
        'spin_started_at_ms': spinStartedAtMs,
        'duration_ms': durationMs,
        'final_angle_deg': finalAngleDeg,
        'winner_restaurant_id': winnerRestaurantId,
      };
}

class SplitGroup {
  final int restaurantId;
  final String name;
  final String? imageUrl;
  final List<String> participantIds;

  const SplitGroup({
    required this.restaurantId,
    required this.name,
    this.imageUrl,
    this.participantIds = const [],
  });

  factory SplitGroup.fromJson(Map<String, dynamic> j) => SplitGroup(
        restaurantId: (j['restaurant_id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
        participantIds: [for (final p in (j['participant_ids'] ?? const []) as List) '$p'],
      );

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'name': name,
        'image_url': imageUrl,
        'participant_ids': participantIds,
      };
}

class SplitState {
  final List<SplitGroup> groups;
  final bool confirmed;

  const SplitState({required this.groups, this.confirmed = false});

  factory SplitState.fromJson(Map<String, dynamic> j) => SplitState(
        groups: [for (final g in (j['groups'] ?? const []) as List) SplitGroup.fromJson(g as Map<String, dynamic>)],
        confirmed: j['confirmed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'groups': [for (final g in groups) g.toJson()],
        'confirmed': confirmed,
      };
}

class DisputeState {
  final String reason; // "no_consensus" | "host_requested"
  final List<DisputeContender> contenders;
  final Map<String, String> methodVotes; // participant_id -> "wheel" | "split"
  final String? method; // null | "wheel" | "split"
  final WheelState? wheel;
  final SplitState? split;

  const DisputeState({
    required this.reason,
    required this.contenders,
    this.methodVotes = const {},
    this.method,
    this.wheel,
    this.split,
  });

  factory DisputeState.fromJson(Map<String, dynamic> j) => DisputeState(
        reason: (j['reason'] ?? 'no_consensus') as String,
        contenders: [for (final c in (j['contenders'] ?? const []) as List) DisputeContender.fromJson(c as Map<String, dynamic>)],
        methodVotes: {
          for (final e in ((j['method_votes'] ?? const {}) as Map).entries) '${e.key}': '${e.value}',
        },
        method: j['method'] as String?,
        wheel: j['wheel'] == null ? null : WheelState.fromJson(j['wheel'] as Map<String, dynamic>),
        split: j['split'] == null ? null : SplitState.fromJson(j['split'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'contenders': [for (final c in contenders) c.toJson()],
        'method_votes': methodVotes,
        'method': method,
        'wheel': wheel?.toJson(),
        'split': split?.toJson(),
      };
}

class Room {
  final String roomCode;
  final RoomMode mode;
  final RoomStage stage;
  final int version;
  final String hostId;
  final String joinUrl;
  final SwipeLevel? level;
  final RoomSettings settings;
  final List<Participant> participants;
  final DisputeState? dispute;
  final int serverOffsetMs; // clientNow - serverDate (approx)

  const Room({
    required this.roomCode,
    required this.mode,
    required this.stage,
    required this.version,
    required this.hostId,
    required this.joinUrl,
    this.level,
    this.settings = const RoomSettings(),
    this.participants = const [],
    this.dispute,
    this.serverOffsetMs = 0,
  });

  Participant? participantById(String? id) {
    if (id == null) return null;
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory Room.fromJson(Map<String, dynamic> j, {int serverOffsetMs = 0}) => Room(
        roomCode: '${j['room_code']}',
        mode: RoomMode.parse(j['mode'] as String?),
        stage: RoomStage.parse(j['stage'] as String?),
        version: (j['version'] as num?)?.toInt() ?? 0,
        hostId: '${j['host_id']}',
        joinUrl: (j['join_url'] ?? '') as String,
        level: SwipeLevel.parse(j['level'] as String?),
        settings: RoomSettings.fromJson(j['settings'] as Map<String, dynamic>?),
        participants: [for (final p in (j['participants'] ?? const []) as List) Participant.fromJson(p as Map<String, dynamic>)],
        dispute: j['dispute'] == null ? null : DisputeState.fromJson(j['dispute'] as Map<String, dynamic>),
        serverOffsetMs: serverOffsetMs,
      );

  Map<String, dynamic> toJson() => {
        'room_code': roomCode,
        'mode': mode.wire,
        'stage': stage.wire,
        'version': version,
        'host_id': hostId,
        'join_url': joinUrl,
        'level': level?.wire,
        'settings': settings.toJson(),
        'participants': [for (final p in participants) p.toJson()],
        'dispute': dispute?.toJson(),
      };
}

class SwipeCard {
  final String id;
  final SwipeLevel level;
  final String title;
  final String subtitle;
  final String description;
  final String cuisine;
  final double? rating;
  final int? etaMinutes;
  final String? imageUrl;
  final List<String> topDishes;

  const SwipeCard({
    required this.id,
    required this.level,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.cuisine = '',
    this.rating,
    this.etaMinutes,
    this.imageUrl,
    this.topDishes = const [],
  });

  factory SwipeCard.fromJson(Map<String, dynamic> j) => SwipeCard(
        id: '${j['id']}',
        level: SwipeLevel.parse(j['level'] as String?) ?? SwipeLevel.category,
        title: (j['title'] ?? j['name'] ?? '') as String,
        subtitle: (j['subtitle'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        cuisine: (j['cuisine'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble(),
        etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
        imageUrl: j['image_url'] as String?,
        topDishes: [for (final d in (j['top_dishes'] ?? const []) as List) '$d'],
      );
}

class CardsResponse {
  final SwipeLevel level;
  final List<SwipeCard> cards;
  const CardsResponse({required this.level, required this.cards});

  factory CardsResponse.fromJson(Map<String, dynamic> j) => CardsResponse(
        level: SwipeLevel.parse(j['level'] as String?) ?? SwipeLevel.category,
        cards: [for (final c in (j['cards'] ?? const []) as List) SwipeCard.fromJson(c as Map<String, dynamic>)],
      );
}

class SwipeResponse {
  final bool ok;
  final bool levelDone;
  const SwipeResponse({required this.ok, required this.levelDone});

  factory SwipeResponse.fromJson(Map<String, dynamic> j) => SwipeResponse(
        ok: j['ok'] != false,
        levelDone: j['level_done'] == true,
      );
}

class ResolutionInfo {
  final String type; // "consensus" | "wheel" | "split"
  const ResolutionInfo({required this.type});

  String get label => switch (type) {
        'wheel' => 'Picked by the wheel',
        'split' => 'Split into groups',
        _ => 'Everyone agreed',
      };

  factory ResolutionInfo.fromJson(Map<String, dynamic>? j) => ResolutionInfo(
        type: (j?['type'] ?? 'consensus') as String,
      );
}

class RestaurantInfo {
  final int id;
  final String name;
  final String? imageUrl;
  final String cuisine;
  final double? rating;
  final String? link;

  const RestaurantInfo({
    required this.id,
    required this.name,
    this.imageUrl,
    this.cuisine = '',
    this.rating,
    this.link,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> j) => RestaurantInfo(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
        cuisine: (j['cuisine'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble(),
        link: j['link'] as String?,
      );
}

class BasketItem {
  final String participantId;
  final String name;
  final String dishName;
  final double price;
  final String? imageUrl;
  final List<String> options;

  const BasketItem({
    required this.participantId,
    required this.name,
    required this.dishName,
    required this.price,
    this.imageUrl,
    this.options = const [],
  });

  factory BasketItem.fromJson(Map<String, dynamic> j) => BasketItem(
        participantId: '${j['participant_id'] ?? ''}',
        name: (j['name'] ?? 'Guest') as String,
        dishName: (j['dish_name'] ?? '') as String,
        price: ((j['price'] ?? 0) as num).toDouble(),
        imageUrl: j['image_url'] as String?,
        options: [for (final o in (j['options'] ?? const []) as List) '$o'],
      );
}

class PersonWhy {
  final String participantId;
  final String name;
  final String why;

  const PersonWhy({required this.participantId, required this.name, required this.why});

  factory PersonWhy.fromJson(Map<String, dynamic> j) => PersonWhy(
        participantId: '${j['participant_id'] ?? ''}',
        name: (j['name'] ?? '') as String,
        why: (j['why'] ?? '') as String,
      );
}

class ResultGroup {
  final String groupId;
  final RestaurantInfo restaurant;
  final List<String> participantIds;
  final List<BasketItem> basket;
  final double totalPrice;
  final String currency;
  final String reasoning;
  final List<PersonWhy> perPerson;

  const ResultGroup({
    required this.groupId,
    required this.restaurant,
    required this.participantIds,
    this.basket = const [],
    this.totalPrice = 0,
    this.currency = 'JOD',
    this.reasoning = '',
    this.perPerson = const [],
  });

  factory ResultGroup.fromJson(Map<String, dynamic> j) => ResultGroup(
        groupId: '${j['group_id'] ?? 'g1'}',
        restaurant: RestaurantInfo.fromJson(j['restaurant'] as Map<String, dynamic>),
        participantIds: [for (final p in (j['participant_ids'] ?? const []) as List) '$p'],
        basket: [for (final b in (j['basket'] ?? const []) as List) BasketItem.fromJson(b as Map<String, dynamic>)],
        totalPrice: ((j['total_price'] ?? 0) as num).toDouble(),
        currency: (j['currency'] ?? 'JOD') as String,
        reasoning: (j['reasoning'] ?? '') as String,
        perPerson: [for (final p in (j['per_person'] ?? const []) as List) PersonWhy.fromJson(p as Map<String, dynamic>)],
      );
}

class TraceStep {
  final int iteration;
  final String tool;
  final Map<String, dynamic> input;
  final String outputSummary;
  final bool failed;

  const TraceStep({
    required this.iteration,
    required this.tool,
    required this.input,
    required this.outputSummary,
    this.failed = false,
  });

  bool get isFailed =>
      failed ||
      outputSummary.toLowerCase().startsWith('failed') ||
      outputSummary.toLowerCase().startsWith('error');

  factory TraceStep.fromJson(Map<String, dynamic> j) => TraceStep(
        iteration: (j['iteration'] as num?)?.toInt() ?? 0,
        tool: (j['tool'] ?? '') as String,
        input: Map<String, dynamic>.from((j['input'] ?? const {}) as Map),
        outputSummary: (j['output_summary'] ?? '') as String,
        failed: j['failed'] == true,
      );
}

enum ResultStatus { running, ready, noMatch, failed }

class RoomResult {
  final ResultStatus status;
  final ResolutionInfo resolution;
  final List<ResultGroup> groups;
  final RestaurantInfo? restaurant;
  final List<BasketItem> basket;
  final double totalPrice;
  final String currency;
  final String reasoning;
  final List<PersonWhy> perPerson;
  final List<TraceStep> trace;

  const RoomResult({
    required this.status,
    this.resolution = const ResolutionInfo(type: 'consensus'),
    this.groups = const [],
    this.restaurant,
    this.basket = const [],
    this.totalPrice = 0,
    this.currency = 'JOD',
    this.reasoning = '',
    this.perPerson = const [],
    this.trace = const [],
  });

  double get grandTotal => groups.isEmpty
      ? totalPrice
      : groups.fold(0.0, (sum, g) => sum + g.totalPrice);

  String get displayCurrency => groups.isNotEmpty ? groups.first.currency : currency;

  factory RoomResult.fromJson(Map<String, dynamic> j) => RoomResult(
        status: switch (j['status']) {
          'ready' => ResultStatus.ready,
          'no_match' => ResultStatus.noMatch,
          'failed' => ResultStatus.failed,
          _ => ResultStatus.running,
        },
        resolution: ResolutionInfo.fromJson(j['resolution'] as Map<String, dynamic>?),
        groups: [for (final g in (j['groups'] ?? const []) as List) ResultGroup.fromJson(g as Map<String, dynamic>)],
        restaurant: j['restaurant'] == null ? null : RestaurantInfo.fromJson(j['restaurant'] as Map<String, dynamic>),
        basket: [for (final b in (j['basket'] ?? const []) as List) BasketItem.fromJson(b as Map<String, dynamic>)],
        totalPrice: ((j['total_price'] ?? 0) as num).toDouble(),
        currency: (j['currency'] ?? 'JOD') as String,
        reasoning: (j['reasoning'] ?? '') as String,
        perPerson: [for (final p in (j['per_person'] ?? const []) as List) PersonWhy.fromJson(p as Map<String, dynamic>)],
        trace: [for (final t in (j['agent_trace'] ?? const []) as List) TraceStep.fromJson(t as Map<String, dynamic>)],
      );
}

class OrderGroupStatus {
  final String groupId;
  final String status;
  final Map<String, dynamic> priceBreakdown;
  final String? restaurantLink;
  final String message;

  const OrderGroupStatus({
    required this.groupId,
    required this.status,
    this.priceBreakdown = const {},
    this.restaurantLink,
    this.message = '',
  });

  factory OrderGroupStatus.fromJson(Map<String, dynamic> j) => OrderGroupStatus(
        groupId: '${j['group_id'] ?? ''}',
        status: (j['status'] ?? 'basket_ready') as String,
        priceBreakdown: Map<String, dynamic>.from((j['price_breakdown'] ?? const {}) as Map),
        restaurantLink: j['restaurant_link'] as String?,
        message: (j['message'] ?? '') as String,
      );
}

class OrderResult {
  final String status; // "basket_ready" | "go" | "failed"
  final List<OrderGroupStatus> groups;

  const OrderResult({required this.status, this.groups = const []});

  factory OrderResult.fromJson(Map<String, dynamic> j) => OrderResult(
        status: (j['status'] ?? 'basket_ready') as String,
        groups: [for (final g in (j['groups'] ?? const []) as List) OrderGroupStatus.fromJson(g as Map<String, dynamic>)],
      );
}
