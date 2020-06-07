const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// when a user followed
exports.onCraeteFollower = functions.firestore.document("/followers/{userId}/userFollowers/{followerId}")
    .onCreate(async (snapshot, context) => {
        const userId = context.params.userId;
        const followerId = context.params.followerId;

        // 1 - craete followed user's posts ref
        const followedUserPostsRef = admin
            .firestore()
            .collection('posts')
            .doc(userId)
            .collection('userPosts');

        //2 - craete following user's timeline ref
        const timelinePostsRef = admin
            .firestore()
            .collection('timeline')
            .doc(followerId)
            .collection('timelinePosts');

        //3- get followed users posts
        const querySnapshot = await followedUserPostsRef.get();

        //4- add aeach users post to following timeline
        querySnapshot.forEach(doc => {
            if (doc.exists) {
                const postId = doc.id;
                const postData = doc.data();
                timelinePostsRef.doc(postId).set(postData);
                console.log("Follower Created", snapshot.id);
            }
        });
    });

// when a user unfollowed
exports.onDeleteFollower = functions.firestore.document("/followers/{userId}/userFollowers/{followerId}")
    .onDelete(async (snapshot, context) => {
        const userId = context.params.userId;
        const followerId = context.params.followerId;

        // 1- ref of timeline of posts by the user
        const timelinePostsRef = admin
            .firestore()
            .collection('timeline')
            .doc(followerId)
            .collection('timelinePosts')
            .where("ownerId", "==", userId);

        //2- get the posts in timeline and delete
        const querySnapshot = await timelinePostsRef.get();
        querySnapshot.forEach(doc => {
            if (doc.exists) {
                doc.ref.delete();
                console.log("Follower deleted", snapshot.id);
            }
        });
    });

// when a post is created - add to post timeline
exports.onCreatePost = functions.firestore.document('/posts/{userId}/userPosts/{postId}')
    .onCreate(async (snapshot, context) => {
        const postCreated = snapshot.data();
        const userId = context.params.userId;
        const postId = context.params.postId;

        //1- get all the followers of the user who made the post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');
        const querySnapshot = await userFollowersRef.get();

        //2- add the new post to each follower's timeline
        querySnapshot.forEach(doc => {
            const followerId = doc.id;

            admin
                .firestore()
                .collection('timeline')
                .doc(followerId)
                .collection('timelinePosts')
                .doc(postId)
                .set(postCreated);
            console.log('Post Created', snapshot.id);
        });

    });

// when a post is updated - add to post timeline
exports.onUpdatePost = functions.firestore.document('/posts/{userId}/userPosts/{postId}')
    .onUpdate(async (chenge, context) => {
        const postUpdated = chenge.after.data();
        const userId = context.params.userId;
        const postId = context.params.postId;

        //1- get all the followers of the user who made the post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');
        const querySnapshot = await userFollowersRef.get();

        //2- update each post in each follower's timeline
        querySnapshot.forEach(doc => {
            const followerId = doc.id;

            admin
                .firestore()
                .collection('timeline')
                .doc(followerId)
                .collection('timelinePosts')
                .doc(postId)
                .get()
                .then(doc => {
                    if (doc.exists) {
                        doc.ref.update(postUpdated);
                        console.log("Post Updated", snapshot.id);
                    }
                });
        });
    });

// when a post is deleted - add to post timeline
exports.onDeletePost = functions.firestore.document('/posts/{userId}/userPosts/{postId}')
    .onDelete(async (snapshot, context) => {
        const userId = context.params.userId;
        const postId = context.params.postId;

        //1- get all the followers of the user who made the post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');
        const querySnapshot = await userFollowersRef.get();

        //2- delete each post in each follower's timeline
        querySnapshot.forEach(doc => {
            const followerId = doc.id;

            admin
                .firestore()
                .collection('timeline')
                .doc(followerId)
                .collection('timelinePosts')
                .doc(postId)
                .get()
                .then(doc => {
                    if (doc.exists) {
                        doc.ref.delete();
                        console.log("Post Deleted", snapshot.id);
                    }
                });
        });
    });

// notification
exports.onCreateActivityFeedItem = functions.firestore.document('/feed/{userId}/feedItems/{activityFeedItem}')
    .onCreate(async (snapshot, context) => {
        console.log('Activity feed item created', snapshot.data);

        // 1 - get the user connected to the feed
        const userId = context.params.userId;

        const userRef = admin.firestore().doc(`users/${userId}`);
        const doc = await userRef.get();

        // 2 - once we have user, check if they have a nnotificaition token - send notification
        const androidNotificationToken = doc.data().androidNotificationToken;
        const createdActivityFeedItem = snapshot.data();
        if (androidNotificationToken) {
            // send notification
            sendNotification(androidNotificationToken, createdActivityFeedItem);
        } else {
            console.log('No Notification Token');
        }

        function sendNotification(androidNotificationToken, activityFeedItem) {
            let body;

            // 3 - switch body value based of notification type
            switch (activityFeedItem.type) {
                case "comment":
                    body = `${activityFeedItem.username} commented: ${activityFeedItem.commentData}`;
                    break;
                case "like":
                    body = `${activityFeedItem.username} liked yout post`;
                    break;
                case "follow":
                    body = `${activityFeedItem.username} started following you`;
                    break;
                default:
                    break;
            }

            // 4 - craete message for push notification
            const message = {
                notification: { body },
                token: androidNotificationToken,
                data: { recipient: userId },
            };

            // 5 - send message with admin.messaging
            admin
                .messaging()
                .send(message)
                .then(response => {
                    // Response is a message ID string
                    console.log('Successfully send message', response);
                })
                .catch(error => {
                    console.log('Error sending message', error);
                });
        }
    });