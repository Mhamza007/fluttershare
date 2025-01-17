import 'package:flutter/material.dart';

AppBar header(BuildContext context,
    {bool isAppTitle = false, titleText: String, backButton = true}) {
  return AppBar(
    automaticallyImplyLeading: backButton ? true : false,
    title: Center(
      child: Text(
        isAppTitle ? 'FlutterShare' : titleText,
        style: TextStyle(
          color: Colors.white,
          fontFamily: isAppTitle ? 'Signatra' : '',
          fontSize: isAppTitle ? 50.0 : 22.0,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    backgroundColor: Theme.of(context).accentColor,
  );
}
