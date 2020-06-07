import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttershare/constants/strings.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String photoUrl;
  final String displayName;
  final String bio;

  User({
    this.id,
    this.username,
    this.email,
    this.photoUrl,
    this.displayName,
    this.bio,
  });

  factory User.fromDocument(DocumentSnapshot doc) {
    return User (
      id: doc[ID],
      username: doc[USERNAME],
      email: doc[EMAIL],
      displayName: doc[DISPLAYNAME],
      photoUrl: doc[PHOTOURL],
      bio: doc[BIO],
    );
  }
}
