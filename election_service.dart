import 'package:cloud_firestore/cloud_firestore.dart';

class ElectionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // ELECTIONS (POLLS)
  // =========================

  /// ✅ List elections (Admin/User)
  /// Solution A: NO orderBy when filtering (avoids composite index requirement)
  static Stream<QuerySnapshot<Map<String, dynamic>>> electionsStream({String? status}) {
    Query<Map<String, dynamic>> q = _db.collection('elections');

    if (status != null) {
      q = q.where('status', isEqualTo: status.trim().toLowerCase());
    }

    // ❌ Intentionally no orderBy here to avoid Firestore index error
    return q.snapshots();
  }

  /// ✅ Officer: list only elections created by officer
  /// Also no orderBy to avoid needing index
  static Stream<QuerySnapshot<Map<String, dynamic>>> myElectionsStream(String officerUid) {
    return _db.collection('elections').where('createdBy', isEqualTo: officerUid).snapshots();
  }

  /// ✅ Create election (each create = new poll)
  static Future<String> createElection({
    required String title,
    required String createdBy,
  }) async {
    final ref = await _db.collection('elections').add({
      'title': title.trim(),
      'createdBy': createdBy,
      'status': 'open', // ✅ default
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// ✅ Update election status: open/closed
  static Future<void> setElectionStatus({
    required String electionId,
    required String status,
  }) async {
    final s = status.trim().toLowerCase();
    if (s != 'open' && s != 'closed') {
      throw Exception('INVALID_STATUS');
    }

    await _db.collection('elections').doc(electionId).update({'status': s});
  }

  // =========================
  // PARTIES / CONTESTANTS
  // =========================

  /// ✅ Add party to a specific election
  static Future<void> addParty({
    required String electionId,
    required String name,
    String symbol = '',
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw Exception('EMPTY_PARTY_NAME');

    await _db.collection('elections').doc(electionId).collection('parties').add({
      'name': n,
      'symbol': symbol.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Listen parties for one election
  static Stream<QuerySnapshot<Map<String, dynamic>>> partiesStream(String electionId) {
    // No orderBy to avoid index issues. You can sort in UI if you want.
    return _db.collection('elections').doc(electionId).collection('parties').snapshots();
  }

  // =========================
  // LIVE RESULTS HELPERS
  // =========================

  /// ✅ Live vote count per party (for LiveResults / Monitor)
  static Stream<int> partyVoteCountStream({
    required String electionId,
    required String partyId,
  }) {
    return _db
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .where('partyId', isEqualTo: partyId)
        .snapshots()
        .map((snap) => snap.size);
  }

  // =========================
  // VOTING
  // =========================

  /// ✅ Global one-time vote in entire system.
  /// - If user tries to vote again in any poll -> throws ALREADY_VOTED
  ///
  /// It writes:
  /// elections/{electionId}/votes/{uid}
  /// and updates:
  /// users/{uid}.hasVoted = true
  static Future<void> voteOnceGlobal({
    required String electionId,
    required String uid,
    required String partyId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final voteRef = _db.collection('elections').doc(electionId).collection('votes').doc(uid);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('USER_DOC_MISSING');

      final data = userSnap.data() ?? {};
      final hasVoted = (data['hasVoted'] ?? false) as bool;

      // ✅ Global lock
      if (hasVoted) throw Exception('ALREADY_VOTED');

      // ✅ Ensure user can't vote twice in same election either
      final existingVote = await tx.get(voteRef);
      if (existingVote.exists) throw Exception('ALREADY_VOTED');

      tx.set(voteRef, {
        'partyId': partyId,
        'votedAt': FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        'hasVoted': true,
        'votedElectionId': electionId,
        'votedPartyId': partyId,
        'votedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// ✅ Check global voting lock
  static Future<bool> hasVotedGlobal({required String uid}) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    return (doc.data()?['hasVoted'] ?? false) as bool;
  }

  /// ✅ Check if voted in a specific election (local per-election)
  static Future<bool> hasVotedInElection({
    required String electionId,
    required String uid,
  }) async {
    final voteDoc = await _db.collection('elections').doc(electionId).collection('votes').doc(uid).get();
    return voteDoc.exists;
  }
}