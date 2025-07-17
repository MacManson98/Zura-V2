// File: lib/utils/tmdb_api.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../movie.dart';
import '../utils/debug_loader.dart';

const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

class StreamingProvider {
  final int providerId;
  final String providerName;
  final String logoPath;
  final int displayPriority;

  StreamingProvider({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    required this.displayPriority,
  });

  factory StreamingProvider.fromJson(Map<String, dynamic> json) {
    return StreamingProvider(
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? '',
      logoPath: json['logo_path'] ?? '',
      displayPriority: json['display_priority'] ?? 0,
    );
  }

  String get logoUrl => logoPath.isNotEmpty ? '$imageBaseUrl$logoPath' : '';
}

class WatchProviders {
  final String tmdbLink;
  final List<StreamingProvider> streaming; // flatrate
  final List<StreamingProvider> rent;
  final List<StreamingProvider> buy;

  WatchProviders({
    required this.tmdbLink,
    required this.streaming,
    required this.rent,
    required this.buy,
  });

  factory WatchProviders.fromJson(Map<String, dynamic> json) {
    return WatchProviders(
      tmdbLink: json['link'] ?? '',
      streaming: (json['flatrate'] as List<dynamic>?)
          ?.map((provider) => StreamingProvider.fromJson(provider))
          .toList() ?? [],
      rent: (json['rent'] as List<dynamic>?)
          ?.map((provider) => StreamingProvider.fromJson(provider))
          .toList() ?? [],
      buy: (json['buy'] as List<dynamic>?)
          ?.map((provider) => StreamingProvider.fromJson(provider))
          .toList() ?? [],
    );
  }

  bool get hasAnyOptions => streaming.isNotEmpty || rent.isNotEmpty || buy.isNotEmpty;
  bool get hasStreaming => streaming.isNotEmpty;
}

class TMDBApi {
  static const String apiKey = '44bda25cf25ee68657a9007f51199091';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static const Map<int, String> genreIdToName = {
    28: "Action",
    12: "Adventure",
    16: "Animation",
    35: "Comedy",
    80: "Crime",
    99: "Documentary",
    18: "Drama",
    10751: "Family",
    14: "Fantasy",
    36: "History",
    27: "Horror",
    10402: "Music",
    9648: "Mystery",
    10749: "Romance",
    878: "Sci-Fi",
    10770: "TV Movie",
    53: "Thriller",
    10752: "War",
    37: "Western",
  };

  static const Map<String, int> genreNameToId = {
    "Action": 28,
    "Adventure": 12,
    "Animation": 16,
    "Comedy": 35,
    "Crime": 80,
    "Documentary": 99,
    "Drama": 18,
    "Family": 10751,
    "Fantasy": 14,
    "History": 36,
    "Horror": 27,
    "Music": 10402,
    "Mystery": 9648,
    "Romance": 10749,
    "Science Fiction": 878,
    "TV Movie": 10770,
    "Thriller": 53,
    "War": 10752,
    "Western": 37,
  };

  static Future<List<Movie>> getMoviesByGenres(List<String> genreNames, {int perGenre = 20}) async {
    final Set<Movie> allMovies = {};

    for (final name in genreNames) {
      final genreId = genreNameToId[name];
      if (genreId == null) continue;

      final randomPage = Random().nextInt(5) + 1; // Pages 1-5
      final url = Uri.parse(
        '$baseUrl/discover/movie?api_key=$apiKey&with_genres=$genreId&sort_by=popularity.desc&page=$randomPage'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body)['results'] as List;
        final movies = results.take(perGenre).map((json) => fromTMDB(json)).toList();
        allMovies.addAll(movies);
      } else {
        DebugLogger.log('❌ Failed to fetch movies for genre $name: ${response.statusCode}');
      }
    }

    final shuffled = allMovies.toList()..shuffle();
    return shuffled;
  }

  static Movie fromTMDB(Map<String, dynamic> json) {
    final genreIds = json['genre_ids'] ?? [];
    final genres = List<String>.from(genreIds.map((id) => genreIdToName[id] ?? 'Unknown'));
    final overview = (json['overview'] ?? '').toLowerCase();
    final tags = <String>[];

    if (overview.contains('love')) tags.add('Romantic');
    if (overview.contains('dark') || overview.contains('haunt')) tags.add('Dark');
    if (overview.contains('laugh') || overview.contains('funny') || overview.contains('comedy')) tags.add('Feel-Good');
    if (overview.contains('fight') || overview.contains('battle') || overview.contains('war')) tags.add('Action-Packed');
    if (overview.contains('dream') || overview.contains('reality')) tags.add('Mind-Bending');
    if (overview.contains('journey') || overview.contains('discover')) tags.add('Inspiring');

    return Movie(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown',
      posterUrl: json['poster_path'] != null ? '$imageBaseUrl${json['poster_path']}' : '',
      overview: json['overview'] ?? '',
      genres: genres,
      tags: tags,
      cast: [],
    );
  }

  static Future<Movie?> fetchFullMovieById(String id) async {
    try {
      final detailUrl = Uri.parse('$baseUrl/movie/$id?api_key=$apiKey&append_to_response=credits');
      final response = await http.get(detailUrl);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch movie details by ID');
      }

      final detail = json.decode(response.body);
      final posterUrl = detail['poster_path'] != null ? '$imageBaseUrl${detail['poster_path']}' : '';
      final genres = List<String>.from((detail['genres'] as List).map((g) => g['name']));
      final cast = List<String>.from((detail['credits']['cast'] as List).take(5).map((c) => c['name']));

      return Movie(
        id: detail['id'].toString(),
        title: detail['title'] ?? 'Untitled',
        posterUrl: posterUrl,
        overview: detail['overview'] ?? 'No overview available.',
        genres: genres,
        cast: cast,
        tags: [],
      );
    } catch (e) {
      DebugLogger.log('Error in fetchFullMovieById: $e');
      return null;
    }
  }

  static Future<List<Movie>> getMoviesByIds(List<String> ids) async {
    final movies = <Movie>[];
    for (final id in ids) {
      try {
        final movie = await fetchFullMovieById(id);
        if (movie != null) movies.add(movie);
      } catch (e) {
        DebugLogger.log("❌ Error loading movie $id: $e");
      }
    }
    return movies;
  }

  static Future<List<Movie>> getPopularMovies() async {
    final randomPage = Random().nextInt(10) + 1;
    final url = Uri.parse('$baseUrl/movie/popular?api_key=$apiKey&language=en-US&page=$randomPage');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];

      return results
          .where((movieData) => movieData['adult'] != true)
          .where((movieData) {
            final title = (movieData['title'] ?? '').toLowerCase();
            final overview = (movieData['overview'] ?? '').toLowerCase();
            final bannedWords = ['porn', 'sex', 'erotic', 'lust', 'dare', 'hentai', 'bdsm'];
            return !bannedWords.any((word) => title.contains(word) || overview.contains(word));
          })
          .map((movieData) {
            final genreIds = movieData['genre_ids'] ?? [];
            final genres = List<String>.from(genreIds.map((id) => genreIdToName[id] ?? 'Unknown'));
            final overview = (movieData['overview'] ?? '').toLowerCase();
            final tags = <String>[];

            if (overview.contains('love')) tags.add('Romantic');
            if (overview.contains('dark') || overview.contains('haunt')) tags.add('Dark');
            if (overview.contains('laugh') || overview.contains('funny') || overview.contains('comedy')) tags.add('Feel-Good');
            if (overview.contains('fight') || overview.contains('battle') || overview.contains('war')) tags.add('Action-Packed');
            if (overview.contains('dream') || overview.contains('reality')) tags.add('Mind-Bending');
            if (overview.contains('journey') || overview.contains('discover')) tags.add('Inspiring');

            return Movie(
              id: movieData['id'].toString(),
              title: movieData['title'] ?? 'Unknown',
              posterUrl: movieData['poster_path'] != null ? '$imageBaseUrl${movieData['poster_path']}' : '',
              overview: movieData['overview'] ?? '',
              genres: genres,
              tags: tags,
              cast: [],
            );
          }).toList();
    } else {
      throw Exception('Failed to fetch popular movies');
    }
  }

  static Future<List<Movie>> searchMovies(String query) async {
    final url = Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(query)}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];

      return results.map((movieData) {
        return Movie(
          id: movieData['id'].toString(),
          title: movieData['title'] ?? 'Unknown',
          posterUrl: movieData['poster_path'] != null ? '$imageBaseUrl${movieData['poster_path']}' : '',
          overview: movieData['overview'] ?? '',
          genres: [],
          tags: [],
          cast: [],
        );
      }).toList();
    } else {
      throw Exception('Failed to search movies');
    }
  }

  static Future<int?> searchMovieId(String title) async {
  final url = Uri.parse(
    '$baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(title)}'
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final results = data['results'] as List;
    if (results.isNotEmpty) {
      return results[0]['id'];
    }
  }
  return null;
}

static Future<List<Map<String, String>>> getMovieCast(int movieId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'),
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final cast = data['cast'] as List;

    return cast.take(8).map<Map<String, String>>((actor) {
      return {
        'name': actor['name'] ?? '',
        'character': actor['character'] ?? '',
        'profilePath': actor['profile_path'] != null
            ? '$imageBaseUrl${actor['profile_path']}'
            : '',
      };
    }).toList();
  } else {
    throw Exception('Failed to load cast: ${response.statusCode}');
  }
}

static Future<WatchProviders?> getWatchProviders(String movieId, {String region = 'US'}) async {
  try {
    final url = Uri.parse('$baseUrl/movie/$movieId/watch/providers?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as Map<String, dynamic>?;
      
      if (results != null && results.containsKey(region)) {
        return WatchProviders.fromJson(results[region]);
      }
    }
    
    return null;
  } catch (e) {
    DebugLogger.log('Error fetching watch providers: $e');
    return null;
  }
}

// Helper method to get popular streaming services logos for fallback
static Future<List<StreamingProvider>> getPopularStreamingServices() async {
  try {
    final url = Uri.parse('$baseUrl/watch/providers/movie?api_key=$apiKey&watch_region=US');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;
      
      // Filter for major streaming services
      final majorServices = ['Netflix', 'Disney Plus', 'Amazon Prime Video', 
                           'Hulu', 'HBO Max', 'Apple TV Plus', 'Paramount Plus'];
      
      return results
          .map((provider) => StreamingProvider.fromJson(provider))
          .where((provider) => majorServices.contains(provider.providerName))
          .toList();
    }
    
    return [];
  } catch (e) {
    DebugLogger.log('Error fetching streaming services: $e');
    return [];
  }
}

static Future<List<String>> getTrendingMovieIds({String timeWindow = 'week'}) async {
  try {
    final url = Uri.parse('$baseUrl/trending/movie/$timeWindow?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];

      // Filter out adult content and extract IDs
      final movieIds = results
          .where((movieData) => movieData['adult'] != true)
          .where((movieData) {
            final title = (movieData['title'] ?? '').toLowerCase();
            final overview = (movieData['overview'] ?? '').toLowerCase();
            final bannedWords = ['porn', 'sex', 'erotic', 'lust', 'dare', 'hentai', 'bdsm'];
            return !bannedWords.any((word) => title.contains(word) || overview.contains(word));
          })
          .map((movieData) => movieData['id'].toString())
          .toList();

      DebugLogger.log("✅ Fetched ${movieIds.length} trending movie IDs from TMDB");
      return movieIds;
    } else {
      DebugLogger.log('❌ Failed to fetch trending movies: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    DebugLogger.log('❌ Error fetching trending movies: $e');
    return [];
  }
}

}
