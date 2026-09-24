import 'package:flutter/material.dart';
import '../models/alarm_track.dart';
import '../services/music_search_service.dart';
import '../services/preferences_service.dart';
import '../services/alarm_player_service.dart';

class TrackSelectorModal extends StatefulWidget {
  final Function(AlarmTrack) onTrackSelected;

  const TrackSelectorModal({super.key, required this.onTrackSelected});

  @override
  State<TrackSelectorModal> createState() => _TrackSelectorModalState();
}

class _TrackSelectorModalState extends State<TrackSelectorModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customUrlController = TextEditingController();
  final TextEditingController _customTitleController = TextEditingController();

  List<AlarmTrack> _searchResults = [];
  bool _isLoading = false;
  String? _previewingTrackId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Pre-populate with popular alarm-friendly tracks
    _performSearch('Wake up energetic');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customUrlController.dispose();
    _customTitleController.dispose();
    AlarmPlayerService.instance.stop();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final results = await MusicSearchService.searchTracks(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _togglePreview(AlarmTrack track) {
    if (_previewingTrackId == track.id && AlarmPlayerService.instance.isPlaying) {
      AlarmPlayerService.instance.stop();
      setState(() => _previewingTrackId = null);
    } else {
      AlarmPlayerService.instance.playPreview(track);
      setState(() => _previewingTrackId = track.id);
    }
  }

  void _chooseTrack(AlarmTrack track) async {
    await PreferencesService.instance.setSelectedTrack(track);
    widget.onTrackSelected(track);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF10141E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Alarm Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00E5FF),
            labelColor: const Color(0xFF00E5FF),
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.search), text: 'Search Catalog'),
              Tab(icon: Icon(Icons.link), text: 'Custom Stream / URL'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildCustomUrlTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Input Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search Spotify, song name, or artist...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF00E5FF)),
                onPressed: () => _performSearch(_searchController.text),
              ),
              filled: true,
              fillColor: const Color(0xFF1E2638),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),

        // Default local alert option button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            tileColor: const Color(0xFF1A2234),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active, color: Color(0xFF00E676)),
            ),
            title: const Text(
              'Default Crystal Chime',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Works 100% offline (Recommended fallback)',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: () => _chooseTrack(AlarmTrack.defaultTrack),
              child: const Text('SELECT', style: TextStyle(color: Color(0xFF00E676))),
            ),
          ),
        ),

        // Search Results List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
              : _searchResults.isEmpty
                  ? const Center(
                      child: Text(
                        'No tracks found.\nTry typing an artist or song title.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final track = _searchResults[index];
                        final isThisPreviewing = _previewingTrackId == track.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171E2D),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isThisPreviewing
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: track.albumArtUrl != null
                                  ? Image.network(
                                      track.albumArtUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.white10,
                                        child: const Icon(Icons.music_note, color: Colors.white54),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.white10,
                                      child: const Icon(Icons.music_note, color: Colors.white54),
                                    ),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isThisPreviewing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: isThisPreviewing ? const Color(0xFF00E5FF) : Colors.white70,
                                    size: 32,
                                  ),
                                  onPressed: () => _togglePreview(track),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _chooseTrack(track),
                                  child: const Text('USE', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCustomUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direct Audio Stream / Web API Endpoint',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter any direct MP3, AAC stream, or Web API audio link. If this stream is ever offline, the fallback chime will ring automatically.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _customTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Alarm Title (e.g. Morning Wakeup Radio)',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF1E2638),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Stream URL (http://... or https://...)',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF1E2638),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text(
                'SET CUSTOM ALARM TRACK',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () {
                final url = _customUrlController.text.trim();
                final title = _customTitleController.text.trim().isEmpty
                    ? 'Custom Stream Alarm'
                    : _customTitleController.text.trim();

                if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid HTTP/HTTPS URL.')),
                  );
                  return;
                }

                final customTrack = AlarmTrack(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  artist: 'Custom Web Stream',
                  previewUrl: url,
                  source: 'custom',
                );

                _chooseTrack(customTrack);
              },
            ),
          ),
        ],
      ),
    );
  }
}
