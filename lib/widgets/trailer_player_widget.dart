// File: lib/widgets/trailer_player_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/trailer_service.dart';
import '../movie.dart';
import '../utils/themed_notifications.dart';

class TrailerPlayerWidget extends StatefulWidget {
  final Movie movie;
  final bool autoPlay;
  final bool showControls;

  const TrailerPlayerWidget({
    Key? key,
    required this.movie,
    this.autoPlay = false,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<TrailerPlayerWidget> createState() => _TrailerPlayerWidgetState();
}

class _TrailerPlayerWidgetState extends State<TrailerPlayerWidget> {
  MovieTrailer? _trailer;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _webViewLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrailer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadTrailer() async {
    if (_isDisposed) return;
    
    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    } catch (e) {
      return;
    }

    try {
      final trailer = await TrailerService.getTrailerForMovie(widget.movie.id);

      if (!mounted || _isDisposed) return;

      if (trailer != null) {
        try {
          setState(() {
            _trailer = trailer;
            _isLoading = false;
            _hasError = false;
            _webViewLoading = true;
          });
        } catch (e) {
          // Widget was disposed during setState
        }
      } else {
        if (!mounted || _isDisposed) return;
        
        try {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'No trailer available for this movie';
          });
        } catch (e) {
          // Widget was disposed during setState
        }
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      
      try {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load trailer';
        });
      } catch (e) {
        // Widget was disposed during setState
      }
    }
  }

  String _getYouTubeEmbedUrl() {
    if (_trailer == null) return '';
    
    final autoplay = widget.autoPlay ? '1' : '0';
    return 'https://www.youtube.com/embed/${_trailer!.key}?'
           'autoplay=$autoplay&'
           'controls=1&'
           'modestbranding=1&'
           'rel=0&'
           'showinfo=0&'
           'iv_load_policy=3&'
           'enablejsapi=1&'
           'origin=https://zura.app';
  }

  Future<void> _openInYouTube() async {
    if (_isDisposed || _trailer == null) return;
    
    try {
      final url = Uri.parse(_trailer!.youTubeUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted && !_isDisposed) {
          _showErrorSnackbar('Could not open YouTube');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Error opening trailer');
      }
    }
  }

  Future<void> _searchYouTubeTrailer() async {
    if (_isDisposed) return;
    
    try {
      final query = Uri.encodeComponent('${widget.movie.title} trailer');
      final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted && !_isDisposed) {
          _showErrorSnackbar('Could not open YouTube');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Error searching for trailer');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    try {
      ThemedNotifications.showError(context, message);
    } catch (e) {
      // Context might be invalid if disposed
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return Container(
        width: double.infinity,
        height: 200.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12.r),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: 200.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isDisposed) return _buildNoTrailerState();
    if (_isLoading) return _buildLoadingState();
    if (_hasError) return _buildErrorState();
    if (_trailer != null) return _buildPlayerState();
    return _buildNoTrailerState();
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFFE5A00D),
            strokeWidth: 2.w,
          ),
          SizedBox(height: 16.h),
          Text(
            'Finding trailer...',
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF1F1F1F),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white54, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            _errorMessage ?? 'Failed to load trailer',
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: _isDisposed ? null : _loadTrailer,
                  icon: Icon(Icons.refresh, size: 16.sp),
                  label: Text('Retry', style: TextStyle(fontSize: 12.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A00D),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: _isDisposed ? null : _searchYouTubeTrailer,
                  icon: Icon(Icons.search, size: 16.sp),
                  label: Text('Search', style: TextStyle(fontSize: 12.sp)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white30),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoTrailerState() {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, color: Colors.white54, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'No trailer found',
            style: TextStyle(color: Colors.white70, fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            'But you can search for one!',
            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: _isDisposed ? null : _searchYouTubeTrailer,
            icon: Icon(Icons.search, size: 20.sp),
            label: Text('Search on YouTube', style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerState() {
    if (_isDisposed || _trailer == null) {
      return _buildNoTrailerState();
    }

    return Stack(
      children: [
        // WebView Player
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_getYouTubeEmbedUrl()),
          ),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            iframeAllow: "camera; microphone; autoplay; encrypted-media; picture-in-picture",
            iframeAllowFullscreen: true,
            supportZoom: false,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            transparentBackground: true,
          ),
          onLoadStart: (controller, url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _webViewLoading = true;
              });
            }
          },
          onLoadStop: (controller, url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _webViewLoading = false;
              });
            }
          },
          onReceivedError: (controller, request, error) {
            if (!_isDisposed && mounted) {
              setState(() {
                _webViewLoading = false;
                _hasError = true;
                _errorMessage = 'Failed to load video player';
              });
            }
          },
        ),

        // Loading overlay
        if (_webViewLoading)
          Container(
            color: const Color(0xFF1F1F1F),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: const Color(0xFFE5A00D),
                  strokeWidth: 2.w,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Loading player...',
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ),
          ),

        // Custom controls overlay
        if (widget.showControls && !_webViewLoading && !_isDisposed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _trailer!.name.isNotEmpty 
                              ? _trailer!.name 
                              : '${widget.movie.title} Trailer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_trailer!.type.isNotEmpty || _trailer!.official)
                          Row(
                            children: [
                              if (_trailer!.type.isNotEmpty)
                                Text(
                                  _trailer!.type.toUpperCase(),
                                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                                ),
                              if (_trailer!.type.isNotEmpty && _trailer!.official)
                                Text(
                                  ' • ',
                                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                                ),
                              if (_trailer!.official)
                                Text(
                                  'OFFICIAL',
                                  style: TextStyle(color: Colors.green, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openInYouTube,
                    icon: Icon(Icons.open_in_new, color: Colors.white, size: 20.sp),
                    tooltip: 'Open in YouTube',
                    splashRadius: 20.r,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}