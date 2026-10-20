/// A chess club - a lightweight social group players can create, browse,
/// and join (③ from the "次の機能案" feature survey). Deliberately kept to
/// just membership + a per-club rating leaderboard rather than chat/
/// team-vs-team matches, which would each be a much larger feature of
/// their own - this is the same scope cut sibling Komovia apps' own
/// "clubs/teams" gaps were left at when they were last surveyed.
class Club {
  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.memberUids,
    required this.createdAt,
  });

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        createdBy: json['createdBy'] as String,
        memberUids: (json['memberUids'] as List?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> memberUids;
  final DateTime createdAt;

  int get memberCount => memberUids.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'memberUids': memberUids,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// One club member, with the rating used to build the club's internal
/// leaderboard (ClubService.getClubMembers) - deliberately the same
/// `rating` field CpuGameProvider/MatchHistoryService already maintain on
/// `users/{uid}`, not a separate per-club rating track.
class ClubMember {
  ClubMember({
    required this.uid,
    required this.displayName,
    required this.rating,
  });

  final String uid;
  final String displayName;
  final int rating;
}
