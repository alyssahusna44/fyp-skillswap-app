// lib/reviews/user_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserReviewsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    
    try {
      // METHOD 1: Direct query approach (more reliable)
      // Get all reviews for this user
      final reviewsData = await _supabase
          .from('reviews')
          .select('id, reviewer_id, rating, comment, created_at')
          .eq('reviewed_user_id', widget.userId)
          .order('created_at', ascending: false);

      debugPrint('Reviews data received: ${reviewsData.length} reviews');

      // Get reviewer details for each review
      List<Map<String, dynamic>> enrichedReviews = [];
      
      for (var review in reviewsData as List) {
        try {
          // Get reviewer name
          final userData = await _supabase
              .from('users')
              .select('name')
              .eq('id', review['reviewer_id'])
              .maybeSingle();

          // Get reviewer profile picture
          final profileData = await _supabase
              .from('profiles')
              .select('profile_picture_url')
              .eq('id', review['reviewer_id'])
              .maybeSingle();

          enrichedReviews.add({
            'review_id': review['id'],
            'reviewer_id': review['reviewer_id'],
            'reviewer_name': userData?['name'] ?? 'Anonymous',
            'reviewer_profile_pic': profileData?['profile_picture_url'],
            'rating': review['rating'],
            'comment': review['comment'],
            'created_at': review['created_at'],
          });
        } catch (e) {
          debugPrint('Error enriching review ${review['id']}: $e');
          // Add review with partial data
          enrichedReviews.add({
            'review_id': review['id'],
            'reviewer_id': review['reviewer_id'],
            'reviewer_name': 'Anonymous',
            'reviewer_profile_pic': null,
            'rating': review['rating'],
            'comment': review['comment'],
            'created_at': review['created_at'],
          });
        }
      }

      // Calculate statistics
      Map<String, dynamic> stats = _calculateStats(reviewsData);

      if (!mounted) return;

      setState(() {
        _reviews = enrichedReviews;
        _stats = stats;
        _isLoading = false;
      });

      debugPrint('Successfully loaded ${_reviews.length} reviews');
      debugPrint('Stats: $_stats');
    } catch (e, stackTrace) {
      debugPrint('Error loading reviews: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reviews: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _calculateStats(List<dynamic> reviewsData) {
    if (reviewsData.isEmpty) {
      return {
        'total_reviews': 0,
        'average_rating': 0.0,
        'five_star': 0,
        'four_star': 0,
        'three_star': 0,
        'two_star': 0,
        'one_star': 0,
      };
    }

    int totalReviews = reviewsData.length;
    double sumRatings = 0;
    int fiveStar = 0, fourStar = 0, threeStar = 0, twoStar = 0, oneStar = 0;

    for (var review in reviewsData) {
      int rating = review['rating'] as int;
      sumRatings += rating;

      switch (rating) {
        case 5:
          fiveStar++;
          break;
        case 4:
          fourStar++;
          break;
        case 3:
          threeStar++;
          break;
        case 2:
          twoStar++;
          break;
        case 1:
          oneStar++;
          break;
      }
    }

    return {
      'total_reviews': totalReviews,
      'average_rating': sumRatings / totalReviews,
      'five_star': fiveStar,
      'four_star': fourStar,
      'three_star': threeStar,
      'two_star': twoStar,
      'one_star': oneStar,
    };
  }

  String _formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Reviews'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Statistics Card
                    if (_stats != null && _stats!['total_reviews'] > 0)
                      _buildStatsCard(),

                    // Reviews List
                    if (_reviews.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _buildReviewCard(_reviews[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final totalReviews = _stats!['total_reviews'] as int;
    final averageRating = (_stats!['average_rating'] as num).toDouble();
    final fiveStar = _stats!['five_star'] as int;
    final fourStar = _stats!['four_star'] as int;
    final threeStar = _stats!['three_star'] as int;
    final twoStar = _stats!['two_star'] as int;
    final oneStar = _stats!['one_star'] as int;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Average Rating
              Expanded(
                child: Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating Distribution
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar(5, fiveStar, totalReviews),
                    _buildRatingBar(4, fourStar, totalReviews),
                    _buildRatingBar(3, threeStar, totalReviews),
                    _buildRatingBar(2, twoStar, totalReviews),
                    _buildRatingBar(1, oneStar, totalReviews),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$stars',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this user!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewer Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: review['reviewer_profile_pic'] != null
                      ? NetworkImage(review['reviewer_profile_pic'])
                      : null,
                  child: review['reviewer_profile_pic'] == null
                      ? Text(
                          (review['reviewer_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['reviewer_name'] ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(review['created_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Star Rating
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        review['rating'].toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Review Comment
            if (review['comment'] != null && 
                review['comment'].toString().isNotEmpty)
              Text(
                review['comment'],
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}