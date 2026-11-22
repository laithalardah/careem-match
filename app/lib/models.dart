/// Models mirror the backend REST contract exactly (see CLAUDE.md).
class Dish {
  final String id, name, cuisine;
  final String? imageUrl;
  const Dish({required this.id, required this.name, required this.cuisine, this.imageUrl});

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: '${j['id']}',
        name: j['name'] as String,
        cuisine: (j['cuisine'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
      );
}

class StartResult {
  final String sessionId;
  final List<Dish> dishes;
  const StartResult(this.sessionId, this.dishes);
}

class Restaurant {
  final int id;
  final String name, cuisine;
  final String? imageUrl;
  final double? rating;
  const Restaurant({required this.id, required this.name, required this.cuisine, this.imageUrl, this.rating});

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        cuisine: (j['cuisine'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
      );
}

class BasketLine {
  final int player;
  final String dishName;
  final double price;
  final String? imageUrl;
  const BasketLine({required this.player, required this.dishName, required this.price, this.imageUrl});

  factory BasketLine.fromJson(Map<String, dynamic> j) => BasketLine(
        player: (j['player'] as num).toInt(),
        dishName: j['dish_name'] as String,
        price: (j['price'] as num).toDouble(),
        imageUrl: j['image_url'] as String?,
      );
}

class TraceStep {
  final int iteration;
  final String tool;
  final Map<String, dynamic> input;
  final String outputSummary;
  const TraceStep({required this.iteration, required this.tool, required this.input, required this.outputSummary});

  factory TraceStep.fromJson(Map<String, dynamic> j) => TraceStep(
        iteration: (j['iteration'] as num).toInt(),
        tool: j['tool'] as String,
        input: Map<String, dynamic>.from((j['input'] ?? const {}) as Map),
        outputSummary: (j['output_summary'] ?? '') as String,
      );
}

enum ResultStatus { ready, running, failed, noMatch }

class MatchResult {
  final ResultStatus status;
  final Restaurant? restaurant;
  final List<BasketLine> basket;
  final double totalPrice;
  final String currency, reasoning;
  final List<TraceStep> trace;

  const MatchResult({
    required this.status,
    this.restaurant,
    this.basket = const [],
    this.totalPrice = 0,
    this.currency = '',
    this.reasoning = '',
    this.trace = const [],
  });

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        status: switch (j['status']) {
          'ready' => ResultStatus.ready,
          'no_match' => ResultStatus.noMatch,
          'failed' => ResultStatus.failed,
          _ => ResultStatus.running,
        },
        restaurant: j['restaurant'] == null ? null : Restaurant.fromJson(j['restaurant'] as Map<String, dynamic>),
        basket: [for (final b in (j['basket'] ?? const []) as List) BasketLine.fromJson(b as Map<String, dynamic>)],
        totalPrice: ((j['total_price'] ?? 0) as num).toDouble(),
        currency: (j['currency'] ?? '') as String,
        reasoning: (j['reasoning'] ?? '') as String,
        trace: [for (final t in (j['agent_trace'] ?? const []) as List) TraceStep.fromJson(t as Map<String, dynamic>)],
      );
}
