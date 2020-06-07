import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/pages/search.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/constants/strings.dart';

class Timeline extends StatefulWidget {
  final User currentUser;

  Timeline({this.currentUser});

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  List<Post> posts;
  List<String> followingList = [];

  @override
  void initState() {
    super.initState();

    getTimeline();
    getFollowing();
  }

  getTimeline() async {
    QuerySnapshot snapshot = await timelineRef
        .document(widget.currentUser.id)
        .collection(TIMELINE_POSTS_COLLECTION)
        .orderBy(TIMESTAMP, descending: true)
        .getDocuments();
    List<Post> posts =
        snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();

    setState(() {
      this.posts = posts;
    });
  }

  getFollowing() async {
    QuerySnapshot snapshot = await followingRef
        .document(currentUser.id)
        .collection(USER_FOLLOWING_COLLECTION)
        .getDocuments();

    setState(() {
      followingList = snapshot.documents.map((doc) => doc.documentID).toList();
      print(followingList);
    });
  }

  buildUsersToFollow() {
    return StreamBuilder(
      stream:
          usersRef.orderBy(TIMESTAMP, descending: true).limit(30).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          print('snapshot data empty');
          return circularProgress(context);
        }
        List<UserResult> userResults = [];
        snapshot.data.documents.forEach(
          (doc) {
            User user = User.fromDocument(doc);
            print(user);
            final bool isCurrentUser =
                currentUser.id == user.id; // is current user
            final bool isFollowingUser =
                followingList.contains(user.id); // already following
            // remove isCurrentUser from list
            if (isCurrentUser) {
              return;
            } else if (isFollowingUser) {
              return;
            } else {
              UserResult userResult = UserResult(user);
              userResults.add(userResult);
              print(userResult);
            }
          },
        );
        return Container(
          color: Theme.of(context).accentColor.withOpacity(0.2),
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.person_add,
                      color: Theme.of(context).primaryColor,
                      size: 30,
                    ),
                    SizedBox(
                      width: 20,
                    ),
                    Expanded(
                      child: Text(
                        'Suggested Users to Follow',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 25.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: userResults,
              ),
            ],
          ),
        );
      },
    );
  }

  buildTimeline() {
    if (posts == null) {
      return circularProgress(context);
    } else if (posts.isEmpty) {
      return Center(
        child: buildUsersToFollow(),
      );
    } else {
      return ListView(children: posts);
    }
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: header(context, isAppTitle: true),
      body: RefreshIndicator(
        child: buildTimeline(),
        onRefresh: () => getTimeline(),
      ),
    );
  }
}
