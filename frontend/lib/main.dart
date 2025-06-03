import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Основная точка входа в приложение
void main() {
  runApp(FrameApp());
}

/// Главный виджет приложения Frame
/// Использует MaterialApp для Material Design
class FrameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame - AI Cinema',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Темная тема по умолчанию
        brightness: Brightness.dark,
        primaryColor: Color(0xFFE50914), // Красный как у Netflix
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        fontFamily: 'Inter',
      ),
      home: HomeScreen(),
    );
  }
}

/// Главный экран приложения
/// Содержит список фильмов и навигацию
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // API endpoint - замените на ваш реальный URL
final String apiUrl = 'http://5.144.179.63'; // Обратите внимание: без /api/ на конце, если ваш фронтенд добавляет его потом


  // Список фильмов, загруженных с сервера
  List<Movie> movies = [];
  
  // Флаг загрузки данных
  bool isLoading = true;
  
  // Текущая тема (темная/светлая)
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    // Загружаем фильмы при инициализации
    fetchMovies();
  }

  /// Загрузка списка фильмов с API
  Future<void> fetchMovies() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/movies'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          movies = data.map((json) => Movie.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        // В случае ошибки показываем заглушку
        _showError('Failed to load movies');
      }
    } catch (e) {
      // Обработка сетевых ошибок
      _showError('Network error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Показ сообщения об ошибке
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Переключение темы
  void _toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        // Кастомный AppBar
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'frame',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: Color(0xFFE50914),
            ),
          ),
          actions: [
            // Кнопка переключения темы
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
            // Кнопка профиля
            IconButton(
              icon: Icon(Icons.person_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
          ],
        ),
        
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchMovies,
                child: CustomScrollView(
                  slivers: [
                    // Hero секция с featured фильмом
                    SliverToBoxAdapter(
                      child: _buildHeroSection(),
                    ),
                    
                    // Секция "Популярное"
                    SliverToBoxAdapter(
                      child: _buildMovieSection('Popular Now', movies),
                    ),
                    
                    // Секция "Новинки"
                    SliverToBoxAdapter(
                      child: _buildMovieSection('New Releases', 
                        movies.where((m) => m.isNew).toList()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Hero секция с главным фильмом
  Widget _buildHeroSection() {
    if (movies.isEmpty) return SizedBox.shrink();
    
    final featuredMovie = movies.first;
    
    return Container(
      height: 400,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(featuredMovie.posterUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Градиент для читаемости текста
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        padding: EdgeInsets.all(20),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover the World of AI Cinema',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Watch unique movies created by artificial intelligence',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE50914),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: Icon(Icons.play_arrow),
              label: Text('Watch'),
              onPressed: () => _openMovieDetails(featuredMovie),
            ),
          ],
        ),
      ),
    );
  }

  /// Секция с горизонтальным списком фильмов
  Widget _buildMovieSection(String title, List<Movie> sectionMovies) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sectionMovies.length,
              itemBuilder: (context, index) {
                return _buildMovieCard(sectionMovies[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка фильма
  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () => _openMovieDetails(movie),
      child: Container(
        width: 130,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Постер фильма
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                movie.posterUrl,
                height: 150,
                width: 130,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Заглушка при ошибке загрузки
                  return Container(
                    height: 150,
                    width: 130,
                    color: Colors.grey[800],
                    child: Icon(Icons.movie, size: 50),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            // Название фильма
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            // Рейтинг
            Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  movie.rating.toString(),
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Открытие детальной страницы фильма
  void _openMovieDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: movie),
      ),
    );
  }
}

/// Экран с деталями фильма
class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;

  MovieDetailsScreen({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Постер фильма на весь экран
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    movie.posterUrl,
                    fit: BoxFit.cover,
                  ),
                  // Кнопка воспроизведения
                  Center(
                    child: IconButton(
                      icon: Icon(Icons.play_circle_filled, size: 80),
                      color: Colors.white.withOpacity(0.9),
                      onPressed: () {
                        // TODO: Implement video playback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playing ${movie.title}')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Информация о фильме
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок и рейтинг
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            movie.rating.toString(),
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  // Метаданные
                  Row(
                    children: [
                      Chip(label: Text(movie.genre)),
                      SizedBox(width: 8),
                      Text('${movie.duration} min'),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Описание
                  Text(
                    movie.description,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: 24),
                  
                  // Кнопки действий
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFE50914),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(Icons.play_arrow),
                        label: Text('Play'),
                        onPressed: () {
                          // TODO: Implement playback
                        },
                      ),
                      SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('My List'),
                        onPressed: () {
                          // TODO: Add to favorites
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Экран профиля пользователя
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Аватар
            CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFFE50914),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            SizedBox(height: 20),
            
            // Имя пользователя
            Text(
              'User',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            
            // Статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('24', 'Watched'),
                _buildStatItem('8', 'Favorites'),
                _buildStatItem('3', 'Uploaded'),
              ],
            ),
            SizedBox(height: 40),
            
            // Кнопка выхода
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: Text('Logout'),
              onPressed: () {
                // TODO: Implement logout
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Элемент статистики
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE50914),
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

/// Модель данных фильма
/// Соответствует структуре API
class Movie {
  final int id;
  final String title;
  final String genre;
  final int duration;
  final double rating;
  final String description;
  final String posterUrl;
  final bool isNew;

  Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.duration,
    required this.rating,
    required this.description,
    required this.posterUrl,
    this.isNew = false,
  });

  /// Создание объекта из JSON
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      genre: json['genre'],
      duration: json['duration'],
      rating: json['rating'].toDouble(),
      description: json['description'],
      posterUrl: json['poster_url'],
      isNew: json['is_new'] ?? false,
    );
  }
}