import 'package:flutter/material.dart';
import '../services/streaming_service.dart';

class LiveStreamCard extends StatelessWidget {
  const LiveStreamCard({required this.stream, super.key, this.onTap});
  final LiveStream stream;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(12),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 60,
            height: 60,
            color: Colors.red,
            child: const Center(
                child: Text('LIVE',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          title: Text(stream.title),
          subtitle: Text('${stream.viewerCount} viewers'),
        ),
      );
}

class VideoTutorialCard extends StatelessWidget {
  const VideoTutorialCard({required this.video, super.key, this.onPlay});
  final VideoContent video;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(video.thumbnailUrl, height: 200, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: onPlay, child: const Text('Watch')),
                ],
              ),
            ),
          ],
        ),
      );
}
