import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:fluttershare/pages/create_account.dart';
import 'package:fluttershare/pages/profile.dart';
import 'package:fluttershare/pages/search.dart';
import 'package:fluttershare/pages/timeline.dart';
import 'package:fluttershare/pages/upload.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttershare/constants/strings.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final usersRef = Firestore.instance.collection(USER_COLLECTION);
final postsRef = Firestore.instance.collection(POSTS_COLLECTION);
final timelineRef = Firestore.instance.collection(TIMELINE_COLLECTION);
final commentsRef = Firestore.instance.collection(COMMENTS_COLLECTION);
final activityFeedRef = Firestore.instance.collection(FEED_COLLECTION);
final followersRef = Firestore.instance.collection(FOLLOWER_COLLECTION);
final followingRef = Firestore.instance.collection(FOLLOWING_COLLECTION);
final StorageReference storageRef = FirebaseStorage.instance.ref();
final DateTime timestamp = DateTime.now();
User currentUser;

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isAuth = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  PageController pageController;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();

    // detects when user signed in
    googleSignIn.onCurrentUserChanged.listen(
      (GoogleSignInAccount account) {
        handleSignIn(account);
      },
      onError: (err) {
        print('Error Signing in: $err');
      },
    );

    // reauthenticate when app is opened (again)
    // try {
    //   googleSignIn
    //       .signInSilently(suppressErrors: false)
    //       .then((GoogleSignInAccount account) {
    //     handleSignIn(account);
    //   }).catchError((err) {
    //     print('Error Signing in: $err');
    //   });
    // } catch (e) {
    //   print('Exception Signing in: $e');
    // }

    pageController = PageController();
  }

  handleSignIn(GoogleSignInAccount account) async {
    if (account != null) {
      await createUserInFirestore();
      setState(() {
        isAuth = true;
      });
      configurePushNotification();
    } else {
      setState(() {
        isAuth = false;
      });
    }
  }

  getiOSPermission() {
    _firebaseMessaging.requestNotificationPermissions(IosNotificationSettings(
      alert: true,
      badge: true,
      sound: true,
    ));
    _firebaseMessaging.onIosSettingsRegistered.listen((settings) {
      print('Settings Registered for iOS $settings');
    });
  }

  configurePushNotification() {
    final GoogleSignInAccount user = googleSignIn.currentUser;
    if (Platform.isIOS) getiOSPermission();

    _firebaseMessaging.getToken().then((token) {
      print('Firebase Messaging Token: $token\n');
      usersRef
          .document(user.id)
          .updateData({ANDROID_NOTIFICATION_TOKEN: token});
    });

    _firebaseMessaging.configure(
      // user is not using the app
      // onLaunch: (Map<String, dynamic> message) async {},

      // user is using app but in background
      // onResume: (Map<String, dynamic> message) async {},

      // user is in-app
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message\n");
        final String recipientId = message['data']['recipient'];
        final String body = message['notification']['body'];

        if (recipientId == user.id) {
          print('Notification shown');
          SnackBar snackBar = SnackBar(
            content: Text(
              '$body',
              overflow: TextOverflow.ellipsis,
            ),
          );
          _scaffoldKey.currentState.showSnackBar(snackBar);
        }
      },
    );
  }

  createUserInFirestore() async {
    // 1- check if user exists in users collection in db
    final GoogleSignInAccount user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.document(user.id).get();

    // 2- if user doesn't exists, take them to create account page
    if (!doc.exists) {
      final username = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateAccount(),
        ),
      );

      // 3- get username from create account - save to firestore
      usersRef.document(user.id).setData({
        ID: user.id,
        USERNAME: username,
        PHOTOURL: user.photoUrl,
        EMAIL: user.email,
        DISPLAYNAME: user.displayName,
        BIO: '',
        TIMESTAMP: timestamp,
      });
      // make new user their own follower - to display current user posts in timeline
      await followersRef
          .document(user.id)
          .collection(USER_FOLLOWERS_COLLECTION)
          .document(user.id)
          .setData({});

      doc = await usersRef.document(user.id).get();
    }

    currentUser = User.fromDocument(doc);
    print(currentUser);
    print(currentUser.username);
    print(currentUser.displayName);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  signIn() {
    googleSignIn.signIn();
  }

  signOut() {
    print('sign out pressed');
    googleSignIn.signOut();
  }

  onPageChanged(int pageIndex) {
    setState(() {
      this.pageIndex = pageIndex;
    });
  }

  onPageTap(int pageIndex) {
    pageController.animateToPage(
      pageIndex,
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Widget buildAuthScreen() {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        child: PageView(
          children: <Widget>[
            Timeline(currentUser: currentUser),
            ActivityFeed(),
            Upload(currentUser: currentUser),
            Search(),
            Profile(profileId: currentUser?.id),
          ],
          controller: pageController,
          onPageChanged: onPageChanged,
          physics: NeverScrollableScrollPhysics(),
        ),
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: pageIndex,
        onTap: onPageTap,
        activeColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.photo_camera,
              size: 35.0,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
          ),
        ],
      ),
    );
  }

  Widget buildUnAuthScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).accentColor,
              Theme.of(context).primaryColor,
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'Flutter Share',
              style: TextStyle(
                fontFamily: 'Signatra',
                fontSize: 90.0,
                color: Colors.white,
              ),
            ),
            SizedBox(
              height: 40.0,
            ),
            GestureDetector(
              onTap: signIn,
              child: Container(
                width: 260.0,
                height: 60.0,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/google_signin_button.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isAuth ? buildAuthScreen() : buildUnAuthScreen();
  }
}
