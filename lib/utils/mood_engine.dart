// Enhanced Mood Engine with Massively Expanded Exemplar Lists
// This replaces your mood_engine.dart with much larger curated lists

import '../movie.dart';
import '../utils/debug_loader.dart';

// SessionContext class from your original code
class SessionContext {
  final CurrentMood moods;
  final DateTime startTime;
  final List<String> groupMemberIds;
  
  SessionContext({
    required this.moods,
    required this.groupMemberIds,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();
}

enum CurrentMood {
  pureComedy('Pure Comedy', '😂', ['Comedy'], ['Funny', 'Silly', 'Upbeat', 'Light-Hearted', 'Hilarious', 'Witty']),
  epicAction('Epic Action', '💥', ['Action'], ['Action-Packed', 'High Stakes', 'Fast-Paced', 'Adrenaline', 'Intense', 'Explosive']),
  scaryAndSuspenseful('Fear & Suspense', '😱', ['Horror', 'Thriller'], ['Scary', 'Suspenseful', 'Dark', 'Creepy', 'Terrifying', 'Spine-Chilling']),
  romantic('Romantic', '💕', ['Romance'], ['Romantic', 'Sweet', 'Heartwarming', 'Love Story', 'Passionate', 'Tender']),
  mindBending('Mind-Bending', '🤔', ['Drama', 'Science Fiction', 'Mystery', 'Thriller'], ['Mind-Bending', 'Complex', 'Thought-Provoking', 'Twist', 'Cerebral', 'Psychological']),
  emotionalDrama('Emotional Drama', '💭', ['Drama'], ['Emotional', 'Heartwarming', 'Moving', 'Deep', 'Touching', 'Meaningful']),
  trueStories('True Stories', '📖', ['Biography', 'History', 'Drama', 'Documentary'], ['Based on a True Story', 'Real Events', 'True Story', 'Historical', 'Biographical']),
  mysteryCrime('Mystery & Crime', '🔍', ['Crime', 'Mystery', 'Thriller'], ['Mystery', 'Crime', 'Investigation', 'Detective', 'Intrigue', 'Puzzle']),
  adventureFantasy('Epic Worlds', '🗺️', ['Adventure', 'Fantasy', 'Science Fiction'], ['Epic', 'Adventure', 'Journey', 'Fantasy', 'Magical', 'Otherworldly']),
  musicalDance('Musical & Dance', '🎵', ['Music'], ['Uplifting', 'Musical', 'Dance']),
  familyFun('Family Fun', '👨‍👩‍👧‍👦', ['Family', 'Animation'], ['Family-Friendly', 'Kids', 'Wholesome']),
  sciFiFuture('Sci-Fi & Future', '🚀', ['Science Fiction'], ['Futuristic', 'Space', 'Technology']),
  worldCinema('World Cinema', '🌍', ['Foreign', 'Drama'], ['International', 'Cultural', 'Subtitled']),
  cultClassic('Cult Classic', '🎞️', ['Drama', 'Comedy', 'Horror'], ['Cult Classic', 'Underground', 'Retro', 'Campy', 'Weird', 'Quirky', 'B-Movie', 'Niche']),
  twistEnding('Twist Ending', '🔄', ['Thriller', 'Mystery', 'Drama'], ['Plot Twist', 'Surprise Ending', 'Shocking', 'Mind-Bending', 'Unexpected', 'Psychological']),
  highStakes('High Stakes', '🧨', ['Action', 'Thriller', 'Crime'], ['Tension', 'Urgent', 'Unrelenting', 'Time-Sensitive', 'Race Against Time', 'Explosive']);

  const CurrentMood(this.displayName, this.emoji, this.preferredGenres, this.preferredVibes);
  
  final String displayName;
  final String emoji;
  final List<String> preferredGenres;
  final List<String> preferredVibes;
}

class EnhancedMoodEngine {
  
  // Massively expanded exemplar movie lists for complex moods (Tier 3)
  static const Map<String, List<String>> EXEMPLAR_MOVIES = {
    'mind_bending': [
      // Classic Mind-Benders
      'inception', 'memento', 'mulholland drive', 'eternal sunshine of the spotless mind',
      'shutter island', 'black swan', 'donnie darko', 'the prestige', 'fight club',
      'being john malkovich', 'synecdoche new york', 'primer', 'the matrix',
      'existenz', 'vanilla sky', 'total recall', 'blade runner', 'minority report',
      'the machinist', 'requiem for a dream', 'pi', 'solaris', 'ghost in the shell',
      'paprika', 'perfect blue', 'akira', 'serial experiments lain',
      
      // Modern Mind-Benders
      'annihilation', 'ex machina', 'her', 'under the skin', 'arrival', 'interstellar',
      'enemy', 'the lobster', 'swiss army man', 'charlie kaufman movies',
      'adaptation', 'being there', 'the holy mountain', 'eraserhead',
      'meshes of the afternoon', 'persona', 'the seventh seal', '8½',
      
      // Philosophical Mind-Benders
      'the tree of life', 'cloud atlas', 'mr nobody', 'the fountain',
      'a scanner darkly', 'waking life', 'the science of sleep',
      'i heart huckabees', 'stranger than fiction', 'the truman show',
      'pleasantville', 'the purple rose of cairo', 'zelig',
      
      // Time/Reality Benders
      'groundhog day', 'looper', 'predestination', 'coherence', 'the butterfly effect',
      'source code', 'edge of tomorrow', 'about time', 'palm springs',
      'russian doll', 'the endless', 'resolution', 'triangle', 'timecrimes',
      'la jetée', 'alphaville', 'world on a wire', 'the man from earth',
      'primer', 'upstream color', 'sound of my voice', 'another earth',
      
      // Surreal/Experimental
      'synecdoche new york', 'kaufman films', 'lynch films', 'tarkovsky films',
      'antonioni films', 'godard films', 'kurosawa dreams', 'the holy mountain',
      'el topo', 'fantastic planet', 'allegro non troppo', 'mind game',
      'tekkonkinkreet', 'cat soup', 'angel egg', 'belladonna of sadness',
      
      // Recent Mind-Benders
      'tenet', 'midsommar', 'hereditary', 'mandy', 'color out of space',
      'possessor', 'saint maud', 'the lighthouse', 'the witch', 'mother!',
      'sorry to bother you', 'horse girl', 'i thinking of ending things',
      'the platform', 'vivarium', 'saint frances', 'the vast of night',
      
      // International Mind-Benders
      'burning', 'shoplifters', 'parasite', 'oldboy', 'the handmaiden',
      'memories of murder', 'mother', 'the wailing', 'train to busan',
      'climax', 'gaspar noé films', 'holy motors', 'the skin i live in',
      'talk to her', 'all about my mother', 'women on the verge',
      'volver', 'amour', 'caché', 'funny games', 'the piano teacher',
    ],
    
    'twist_ending': [
      // Classic Twist Movies
      'the sixth sense', 'the usual suspects', 'fight club', 'the prestige',
      'memento', 'shutter island', 'gone girl', 'the others', 'orphan',
      'the village', 'unbreakable', 'split', 'glass', 'signs',
      'the happening', 'lady in the water', 'wide awake', 'the visit',
      
      // Hitchcock Twists
      'vertigo', 'psycho', 'rear window', 'north by northwest', 'the birds',
      'rope', 'dial m for murder', 'strangers on a train', 'spellbound',
      'notorious', 'the man who knew too much', 'marnie', 'torn curtain',
      
      // Modern Thriller Twists
      'zodiac', 'seven', 'the departed', 'no country for old men',
      'there will be blood', 'nightcrawler', 'prisoners', 'sicario',
      'hell or high water', 'wind river', 'blade runner 2049',
      'knives out', 'glass onion', 'the menu', 'barbarian', 'nope',
      
      // Psychological Twists
      'black swan', 'requiem for a dream', 'american psycho', 'taxi driver',
      'the machinist', 'one hour photo', 'insomnia', 'the game',
      'identity', 'secret window', 'the number 23', 'gothika',
      'jacob ladder', 'angel heart', 'lost highway', 'mulholland drive',
      
      // Horror Twists
      'get out', 'us', 'nope', 'hereditary', 'midsommar', 'the witch',
      'the wicker man', 'rosemarys baby', 'dont look now', 'the changeling',
      'the innocents', 'carnival of souls', 'dead ringers', 'videodrome',
      'scanners', 'the fly', 'they live', 'invasion of the body snatchers',
      'the thing', 'alien', 'aliens', 'predator', 'the mist',
      
      // Sci-Fi Twists
      'planet of the apes', 'soylent green', 'the matrix', 'dark city',
      'the thirteenth floor', 'strange days', 'gattaca', 'minority report',
      'total recall', 'blade runner', 'ex machina', 'her', 'arrival',
      'annihilation', 'under the skin', 'moon', 'source code', 'looper',
      
      // International Twists
      'oldboy', 'the handmaiden', 'parasite', 'burning', 'memories of murder',
      'the wailing', 'i saw the devil', 'a tale of two sisters',
      'audition', 'perfect blue', 'paprika', 'ghost in the shell',
      'battle royale', 'ichi the killer', 'visitor q', 'love exposure',
      
      // Crime/Noir Twists
      'chinatown', 'the maltese falcon', 'double indemnity', 'sunset boulevard',
      'vertigo', 'laura', 'the third man', 'touch of evil', 'the postman always rings twice',
      'out of the past', 'the big sleep', 'murder my sweet', 'the lady from shanghai',
      'l.a. confidential', 'mulholland falls', 'the black dahlia', 'hollywoodland',
      
      // Recent Twists
      'the invisible man', 'midsommar', 'hereditary', 'us', 'get out',
      'sorry to bother you', 'horse girl', 'i thinking of ending things',
      'the platform', 'vivarium', 'color out of space', 'mandy',
      'possessor', 'saint maud', 'the lighthouse', 'the witch',
    ],
    
    'cult_classic': [
      // Tarantino Universe
      'pulp fiction', 'reservoir dogs', 'kill bill', 'kill bill vol 2',
      'jackie brown', 'true romance', 'natural born killers', 'from dusk till dawn',
      'death proof', 'planet terror', 'grindhouse', 'django unchained',
      'inglourious basterds', 'once upon a time in hollywood', 'hateful eight',
      
      // Coen Brothers Cult
      'the big lebowski', 'fargo', 'raising arizona', 'barton fink',
      'miller crossing', 'the hudsucker proxy', 'burn after reading',
      'a serious man', 'inside llewyn davis', 'hail caesar', 'the ballad of buster scruggs',
      'true grit', 'no country for old men', 'blood simple', 'the man who wasnt there',
      
      // Horror Cult Classics
      'the rocky horror picture show', 'evil dead', 'evil dead 2', 'army of darkness',
      'dead alive', 'bad taste', 'meet the feebles', 'brain dead',
      'house', 'hausu', 're-animator', 'return of the living dead',
      'night of the demons', 'the texas chain saw massacre', 'dawn of the dead',
      'day of the dead', 'they live', 'the thing', 'videodrome', 'scanners',
      'the fly', 'dead ringers', 'naked lunch', 'crash', 'existenz',
      'society', 'basket case', 'frankenhooker', 'bad biology',
      'the stuff', 'q the winged serpent', 'its alive', 'god told me to',
      
      // Comedy Cult Classics
      'the room', 'plan 9 from outer space', 'troll 2', 'miami connection',
      'birdemic', 'the happening', 'fateful findings', 'double down',
      'pass thru', 'twisted pair', 'the warriors', 'escape from new york',
      'big trouble in little china', 'they live', 'the princess bride',
      'this is spinal tap', 'best in show', 'waiting for guffman',
      'a mighty wind', 'for your consideration', 'mascots',
      'the big lebowski', 'pee wees big adventure', 'beetlejuice',
      'young frankenstein', 'blazing saddles', 'the producers',
      'life of brian', 'holy grail', 'meaning of life',
      
      // Midnight Movies/Underground
      'eraserhead', 'pink flamingos', 'female trouble', 'desperate living',
      'multiple maniacs', 'mondo trasho', 'polyester', 'hairspray',
      'cry baby', 'serial mom', 'pecker', 'cecil b demented',
      'a dirty shame', 'el topo', 'the holy mountain', 'santa sangre',
      'the dance of reality', 'endless poetry', 'psychomagic',
      'fantastic planet', 'allegro non troppo', 'wizards', 'fire and ice',
      
      // International Cult
      'battle royale', 'oldboy', 'ichi the killer', 'audition', 'tetsuo',
      'house', 'hausu', 'visitor q', 'love exposure', 'tokyo gore police',
      'machine girl', 'vampire girl vs frankenstein girl', 'robogeisha',
      'wild zero', 'versus', 'alive', 'the happiness of the katakuris',
      'dead or alive', 'gozu', 'izo', 'first love', 'blade of the immortal',
      'city of lost children', 'delicatessen', 'amelie', 'micmacs',
      'mood indigo', 'the young and prodigious ts spivet',
      
      // Sci-Fi Cult
      'blade runner', 'akira', 'ghost in the shell', 'serial experiments lain',
      'neon genesis evangelion', 'cowboy bebop', 'perfect blue', 'paprika',
      'spirited away', 'princess mononoke', 'nausicaa', 'castle in the sky',
      'my neighbor totoro', 'kikis delivery service', 'porco rosso',
      'the wind rises', 'grave of the fireflies', 'only yesterday',
      'the red turtle', 'when marnie was there', 'the tale of princess kaguya',
      
      // B-Movies & Exploitation
      'faster pussycat kill kill', 'beyond the valley of the dolls',
      'supervixens', 'up', 'beneath the valley of the ultra vixens',
      'showgirls', 'valley of the dolls', 'mommie dearest', 'what ever happened to baby jane',
      'whatever happened to aunt alice', 'strait jacket', 'berserk',
      'trog', 'i spit on your grave', 'last house on the left',
      'hills have eyes', 'people under the stairs', 'red eye',
      'my soul to take', 'the serpent and the rainbow',
      
      // 80s/90s Cult
      'heathers', 'river edge', 'pump up the volume', 'say anything',
      'better off dead', 'one crazy summer', 'sixteen candles',
      'weird science', 'the breakfast club', 'ferris bueller',
      'pretty in pink', 'some kind of wonderful', 'mannequin',
      'earth girls are easy', 'valley girl', 'fast times at ridgemont high',
      'spicoli', 'bill and ted', 'waynes world', 'dumb and dumber',
      'kingpin', 'theres something about mary', 'dumb and dumber to',
      
      // Lynch & Surreal Cult
      'blue velvet', 'wild at heart', 'lost highway', 'mulholland drive',
      'the straight story', 'twin peaks fire walk with me', 'inland empire',
      'elephant man', 'dune', 'twin peaks the return',
      'eraserhead', 'the grandmother', 'six men getting sick',
      
      // Waters & Transgressive
      'pink flamingos', 'female trouble', 'desperate living', 'multiple maniacs',
      'mondo trasho', 'polyester', 'hairspray', 'cry baby', 'serial mom',
      'pecker', 'cecil b demented', 'a dirty shame',
      
      // Recent Cult Films
      'the room', 'the disaster artist', 'spring breakers', 'only god forgives',
      'neon demon', 'drive', 'blade runner 2049', 'mandy', 'color out of space',
      'possessor', 'saint maud', 'the lighthouse', 'the witch',
      'midsommar', 'hereditary', 'us', 'get out', 'sorry to bother you',
      'horse girl', 'i thinking of ending things', 'the platform',
      'vivarium', 'under the silver lake', 'the love witch',
      'the neon demon', 'spring breakers', 'harmony korine films',
    ]
  };
  
  // Anti-pattern exclusions: Movies with these genres should NOT match certain moods
  static const Map<CurrentMood, List<String>> MOOD_EXCLUSIONS = {
    CurrentMood.pureComedy: ['Family', 'Animation'],           // No family movies in adult comedy
    CurrentMood.epicAction: ['Family', 'Animation'],           // No family movies in adult action
    CurrentMood.scaryAndSuspenseful: ['Family', 'Animation'],  // No family movies in horror (unless genuinely scary)
    CurrentMood.romantic: ['Family', 'Animation'],             // No family movies in adult romance
    CurrentMood.mindBending: ['Family', 'Animation'],          // No family movies in complex narratives
    CurrentMood.emotionalDrama: ['Family', 'Animation'],       // No family movies in adult dramas
    CurrentMood.mysteryCrime: ['Family', 'Animation'],         // No family movies in crime thrillers
    CurrentMood.cultClassic: ['Family', 'Animation'],          // No family movies in cult classics
    CurrentMood.twistEnding: ['Family', 'Animation'],          // No family movies in twist thrillers
    CurrentMood.highStakes: ['Family', 'Animation'],           // No family movies in high-stakes action
  };
  
  // Mood precedence: Higher priority moods win conflicts
  static const Map<CurrentMood, int> MOOD_PRIORITY = {
    CurrentMood.familyFun: 100,           // Family Fun has highest priority
    CurrentMood.scaryAndSuspenseful: 90,  // Horror beats thriller
    CurrentMood.mysteryCrime: 80,         // Crime beats generic thriller
    CurrentMood.pureComedy: 70,           // Pure comedy beats generic comedy
    CurrentMood.epicAction: 70,           // Epic action beats generic action
    CurrentMood.romantic: 60,             // Romance beats generic drama
    CurrentMood.sciFiFuture: 60,          // Sci-fi beats generic drama
    CurrentMood.musicalDance: 60,         // Musical beats generic drama
    CurrentMood.worldCinema: 50,          // World cinema beats generic
    CurrentMood.mindBending: 40,          // Mind-bending needs specific elements
    CurrentMood.twistEnding: 40,          // Twist ending needs specific elements
    CurrentMood.cultClassic: 30,          // Cult classic is very specific
    CurrentMood.trueStories: 20,          // True stories can be broad
    CurrentMood.emotionalDrama: 10,       // Emotional drama is broad
    CurrentMood.adventureFantasy: 10,     // Adventure fantasy is broad
    CurrentMood.highStakes: 10,           // High stakes is broad
  };
  
  /// Main enhanced mood filtering with anti-pattern exclusions
  static List<Movie> filterByMoodCriteria(
    List<Movie> movieDatabase, 
    CurrentMood mood, 
    Set<String> seenMovieIds, 
    Set<String> sessionPassedMovieIds
  ) {
    final moodMovies = <Movie>[];
    final excludedMovieIds = <String>{};
    excludedMovieIds.addAll(seenMovieIds);
    excludedMovieIds.addAll(sessionPassedMovieIds);

    for (final movie in movieDatabase) {
      if (excludedMovieIds.contains(movie.id)) continue;
      if (!_meetsQualityThreshold(movie)) continue;
      if (!_isSfwMovie(movie)) continue;

      if (_isMoviePerfectForMoodEnhanced(movie, mood)) {
        moodMovies.add(movie);
      }
    }

    DebugLogger.log("✅ Enhanced filter found ${moodMovies.length} movies for mood: ${mood.displayName}");
    return moodMovies;
  }
  
  /// Enhanced movie matching with anti-pattern exclusions and exemplar system
  static bool _isMoviePerfectForMoodEnhanced(Movie movie, CurrentMood mood) {
    final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
    final movieTags = movie.tags.map((t) => t.toLowerCase()).toSet();
    
    // Step 1: Check anti-pattern exclusions first
    if (_hasExcludedGenres(movie, mood)) {
      return false;
    }
    
    // Step 2: For Tier 3 moods, check exemplar list using movie title
    if (_isTier3Mood(mood)) {
      final moodType = _getMoodTypeForExemplar(mood);
      if (moodType != null && isExemplarMovieByTitle(movie.title, moodType)) {
        return true; // Exemplar movies always match regardless of tags
      }
    }
    
    // Step 3: Check if movie matches mood criteria
    bool matchesMood = false;
    
    switch (mood) {
      case CurrentMood.pureComedy:
        matchesMood = _isPureComedyEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.epicAction:
        matchesMood = _isEpicActionEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.familyFun:
        matchesMood = _isFamilyFunEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.scaryAndSuspenseful:
        matchesMood = _isScaryAndSuspensefulEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.romantic:
        matchesMood = _isRomanticEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.sciFiFuture:
        matchesMood = _isSciFiFutureEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.worldCinema:
        matchesMood = _isWorldCinemaEnhanced(movie, movieGenres, movieTags);
        break;
        
      case CurrentMood.musicalDance:
        matchesMood = _isMusicalDanceEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.mysteryCrime:
        matchesMood = _isMysteryOrCrimeEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.mindBending:
        matchesMood = _isMindBendingEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.emotionalDrama:
        matchesMood = _isEmotionalDramaEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.trueStories:
        matchesMood = _isTrueStoryEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.adventureFantasy:
        matchesMood = _isAdventureFantasyEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.cultClassic:
        matchesMood = _isCultClassicEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.twistEnding:
        matchesMood = _isTwistEndingEnhanced(movieGenres, movieTags);
        break;
        
      case CurrentMood.highStakes:
        matchesMood = _isHighStakesEnhanced(movieGenres, movieTags);
        break;
    }
    
    return matchesMood;
  }
  
  /// Check if movie has excluded genres for this mood
  static bool _hasExcludedGenres(Movie movie, CurrentMood mood) {
    final excludedGenres = MOOD_EXCLUSIONS[mood];
    if (excludedGenres == null) return false;
    
    final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
    
    for (final excludedGenre in excludedGenres) {
      if (movieGenres.contains(excludedGenre.toLowerCase())) {
        return true; // This movie is excluded from this mood
      }
    }
    
    return false;
  }
  
  // ========================================
  // TIER 3 MOOD HELPERS - PROPERLY DEFINED
  // ========================================
  
  /// Check if mood is a Tier 3 (exemplar-driven) mood
  static bool _isTier3Mood(CurrentMood mood) {
    return mood == CurrentMood.mindBending || 
           mood == CurrentMood.twistEnding || 
           mood == CurrentMood.cultClassic;
  }
  
  /// Get exemplar type string for mood
  static String? _getMoodTypeForExemplar(CurrentMood mood) {
    switch (mood) {
      case CurrentMood.mindBending:
        return 'mind_bending';
      case CurrentMood.twistEnding:
        return 'twist_ending';
      case CurrentMood.cultClassic:
        return 'cult_classic';
      default:
        return null;
    }
  }
  
  // ========================================
  // ENHANCED MOOD-SPECIFIC MATCHING FUNCTIONS
  // ========================================
  
  static bool _isPureComedyEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Comedy genre
    if (!genres.contains('comedy')) return false;
    
    // Must have comedy indicators
    final comedyTags = ['funny', 'hilarious', 'witty', 'humorous', 'comedic'];
    final hasComedyTag = tags.any((tag) => comedyTags.any((comedyTag) => tag.contains(comedyTag)));
    
    // Family movies are already excluded by anti-patterns
    return hasComedyTag;
  }
  
  static bool _isEpicActionEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Action genre
    if (!genres.contains('action')) return false;
    
    // Must have action indicators
    final actionTags = ['action-packed', 'explosive', 'intense', 'high stakes'];
    final hasActionTag = tags.any((tag) => actionTags.any((actionTag) => tag.contains(actionTag)));
    
    // Family movies are already excluded by anti-patterns
    return hasActionTag;
  }
  
  static bool _isFamilyFunEnhanced(Set<String> genres, Set<String> tags) {
    // Family Fun has HIGHEST priority - gets all family content
    if (genres.contains('family') || genres.contains('animation')) {
      return true;
    }
    
    // Also check for family-friendly tags
    final familyTags = ['family-friendly', 'kids', 'wholesome'];
    return tags.any((tag) => familyTags.any((famTag) => tag.contains(famTag)));
  }
  
  static bool _isScaryAndSuspensefulEnhanced(Set<String> genres, Set<String> tags) {
    // Horror movies are automatically included
    if (genres.contains('horror')) return true;
    
    // Thriller movies need scary indicators
    if (genres.contains('thriller')) {
      final scaryTags = ['scary', 'terrifying', 'frightening', 'suspenseful', 'dark/disturbing'];
      return tags.any((tag) => scaryTags.any((scaryTag) => tag.contains(scaryTag)));
    }
    
    return false;
  }
  
  static bool _isRomanticEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Romance genre
    if (!genres.contains('romance')) return false;
    
    // Look for romantic indicators
    final romanticTags = ['romantic', 'love story', 'relationship'];
    return tags.any((tag) => romanticTags.any((romTag) => tag.contains(romTag)));
  }
  
  static bool _isSciFiFutureEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Science Fiction genre (corrected name!)
    if (!genres.contains('science fiction')) return false;
    
    // Look for sci-fi indicators
    final scifiTags = ['sci-fi/techy', 'futuristic', 'space', 'alien', 'technology'];
    return tags.any((tag) => scifiTags.any((scifiTag) => tag.contains(scifiTag)));
  }
  
  static bool _isWorldCinemaEnhanced(Movie movie, Set<String> genres, Set<String> tags) {
    // Non-English movies with quality threshold
    final originalLanguage = movie.originalLanguage ?? 'en';
    if (originalLanguage == 'en') return false;
    
    // Must have decent quality
    final voteCount = movie.voteCount ?? 0;
    return voteCount >= 50; // Higher threshold for world cinema
  }
  
  static bool _isMusicalDanceEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Music genre (corrected name!)
    if (!genres.contains('music')) return false;
    
    // Look for musical indicators
    final musicalTags = ['musical', 'dance', 'singing', 'song'];
    return tags.any((tag) => musicalTags.any((musTag) => tag.contains(musTag)));
  }
  
  static bool _isMysteryOrCrimeEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Crime or Mystery genre
    if (!genres.contains('crime') && !genres.contains('mystery')) return false;
    
    // Look for crime/mystery indicators
    final crimeTags = ['detective', 'investigation', 'murder', 'police'];
    return tags.any((tag) => crimeTags.any((crimeTag) => tag.contains(crimeTag)));
  }
  
  static bool _isMindBendingEnhanced(Set<String> genres, Set<String> tags) {
    // Tier 3: Exemplar-driven + conservative detection
    
    // Step 1: Check exemplar list first (most reliable)
    if (_isExemplarMovie('mind_bending', tags)) {
      return true;
    }
    
    // Step 2: Conservative tag-based detection
    final mindBendingTags = ['mind-bending', 'psychological', 'complex narrative', 'non linear'];
    final hasMindBendingTag = tags.any((tag) => 
        mindBendingTags.any((mbTag) => tag.contains(mbTag)));
    
    if (!hasMindBendingTag) return false;
    
    // Step 3: Must have supporting genre + high quality
    final supportingGenres = ['thriller', 'mystery', 'science fiction', 'drama'];
    final hasSupportingGenre = genres.any((genre) => supportingGenres.contains(genre));
    
    // Step 4: Higher quality threshold for tag-based matches
    return hasSupportingGenre; // Quality check done in _meetsQualityThreshold
  }
  
  static bool _isEmotionalDramaEnhanced(Set<String> genres, Set<String> tags) {
    // Must have Drama genre
    if (!genres.contains('drama')) return false;
    
    // Look for emotional indicators
    final emotionalTags = ['emotional', 'heartwarming', 'moving', 'touching'];
    return tags.any((tag) => emotionalTags.any((emoTag) => tag.contains(emoTag)));
  }
  
  static bool _isTrueStoryEnhanced(Set<String> genres, Set<String> tags) {
    // Multiple genre options
    final validGenres = ['biography', 'history', 'drama', 'documentary'];
    if (!genres.any((genre) => validGenres.contains(genre))) return false;
    
    // Look for true story indicators
    final trueStoryTags = ['based on a true story', 'real events', 'true story', 'biographical'];
    return tags.any((tag) => trueStoryTags.any((tsTag) => tag.contains(tsTag)));
  }
  
  static bool _isAdventureFantasyEnhanced(Set<String> genres, Set<String> tags) {
    // Multiple genre options
    final validGenres = ['adventure', 'fantasy', 'science fiction'];
    if (!genres.any((genre) => validGenres.contains(genre))) return false;
    
    // Look for epic/adventure indicators
    final adventureTags = ['epic', 'adventure', 'journey', 'fantasy', 'magical'];
    return tags.any((tag) => adventureTags.any((advTag) => tag.contains(advTag)));
  }
  
  static bool _isCultClassicEnhanced(Set<String> genres, Set<String> tags) {
    // Tier 3: Ultra-strict exemplar-driven approach
    
    // Step 1: Check exemplar list first (most reliable)
    if (_isExemplarMovie('cult_classic', tags)) {
      return true;
    }
    
    // Step 2: Very strict tag-based detection
    final explicitCultTags = ['cult classic', 'cult film', 'midnight movie'];
    final hasExplicitCultTag = tags.any((tag) => 
        explicitCultTags.any((cultTag) => tag.contains(cultTag)));
    
    if (!hasExplicitCultTag) return false;
    
    // Step 3: Must have supporting characteristics
    final cultCharacteristics = ['weird', 'quirky', 'campy', 'bizarre', 'offbeat', 'surreal'];
    final hasCharacteristics = tags.any((tag) => 
        cultCharacteristics.any((char) => tag.contains(char)));
    
    return hasCharacteristics;
  }
  
  static bool _isTwistEndingEnhanced(Set<String> genres, Set<String> tags) {
    // Tier 3: Ultra-strict exemplar-driven approach
    
    // Step 1: Check exemplar list first (most reliable)
    if (_isExemplarMovie('twist_ending', tags)) {
      return true;
    }
    
    // Step 2: Very strict tag-based detection
    final explicitTwistTags = ['plot twist', 'twist ending', 'surprise ending', 'shocking ending'];
    final hasExplicitTwistTag = tags.any((tag) => 
        explicitTwistTags.any((twistTag) => tag.contains(twistTag)));
    
    if (!hasExplicitTwistTag) return false;
    
    // Step 3: Must have supporting genre
    final supportingGenres = ['thriller', 'mystery', 'horror', 'drama'];
    final hasSupportingGenre = genres.any((genre) => supportingGenres.contains(genre));
    
    // Step 4: Additional twist indicators for validation
    final twistIndicators = ['unexpected', 'revelation', 'shocking', 'mind-bending'];
    final hasIndicators = tags.any((tag) => 
        twistIndicators.any((indicator) => tag.contains(indicator)));
    
    return hasSupportingGenre && hasIndicators;
  }
  
  static bool _isHighStakesEnhanced(Set<String> genres, Set<String> tags) {
    // Must have action/thriller genre
    if (!genres.contains('action') && !genres.contains('thriller')) return false;
    
    // Look for high stakes indicators
    final stakesTags = ['high stakes', 'urgent', 'time-sensitive', 'race against time'];
    return tags.any((tag) => stakesTags.any((stakesTag) => tag.contains(stakesTag)));
  }
  
  // ========================================
  // EXEMPLAR MATCHING SYSTEM
  // ========================================
  
  /// Check if movie title matches known exemplar movies
  static bool _isExemplarMovie(String moodType, Set<String> tags) {
    final exemplars = EXEMPLAR_MOVIES[moodType];
    if (exemplars == null) return false;
    
    // Check if any tag contains movie title fragments
    // This works because your tags often include title elements
    for (final exemplar in exemplars) {
      final exemplarWords = exemplar.toLowerCase().split(' ');
      
      // Check if tags contain significant words from exemplar titles
      for (final word in exemplarWords) {
        if (word.length > 3) { // Skip short words like "the", "of"
          if (tags.any((tag) => tag.contains(word))) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
  
  /// Enhanced exemplar matching using movie title directly
  static bool isExemplarMovieByTitle(String movieTitle, String moodType) {
    final exemplars = EXEMPLAR_MOVIES[moodType];
    if (exemplars == null) return false;
    
    final titleLower = movieTitle.toLowerCase();
    
    // Exact or partial title matching
    for (final exemplar in exemplars) {
      if (titleLower.contains(exemplar.toLowerCase()) || 
          exemplar.toLowerCase().contains(titleLower)) {
        return true;
      }
    }
    
    return false;
  }
  
  // ========================================
  // ENHANCED QUALITY FILTERS
  // ========================================
  
  static bool _meetsQualityThreshold(Movie movie) {
    final rating = movie.rating ?? 0;
    final voteCount = movie.voteCount ?? 0;
    
    // Higher quality threshold for Tier 3 moods
    // (These need to be more reliable)
    if (voteCount < 50 && rating < 6.0) return false;
    
    // Basic quality filter for all other moods
    if (voteCount < 10 && rating < 5.0) return false;
    
    return true;
  }
  
  static bool _isSfwMovie(Movie movie) {
    final title = movie.title.toLowerCase();
    final overview = movie.overview.toLowerCase();
    
    // Filter out adult content
    final bannedWords = ['porn', 'sex', 'erotic', 'lust', 'xxx', 'adult'];
    
    for (final word in bannedWords) {
      if (title.contains(word) || overview.contains(word)) {
        return false;
      }
    }
    
    return true;
  }
}