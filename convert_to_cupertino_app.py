with open('lib/main.dart', 'r') as f:
    content = f.read()

replacement = '''
      child: CupertinoApp.router(
        theme: CupertinoThemeData(
          brightness: overlayBrightness,
          primaryColor: const Color(0xFF007AFF),
          scaffoldBackgroundColor: overlayBrightness == Brightness.dark
              ? MusifiedStyle.oledBlack
              : MusifiedStyle.lightCanvas,
          barBackgroundColor: overlayBrightness == Brightness.dark
              ? MusifiedStyle.elevated
              : MusifiedStyle.lightElevated,
          textTheme: const CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 17,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        builder: (context, child) {
          // Provide Material Theme as a fallback so Material widgets don't crash
          return Theme(
            data: overlayBrightness == Brightness.dark ? themes.dark : themes.light,
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: appSupportedLocales,
        locale: languageSetting,
        routerConfig: NavigationManager.router,
      ),
'''

import re
# regex replace from child: MaterialApp.router( to routerConfig: NavigationManager.router, ),
content = re.sub(r'child: MaterialApp\.router\(.*routerConfig: NavigationManager\.router,\n      \),', replacement.strip('\n'), content, flags=re.DOTALL)

with open('lib/main.dart', 'w') as f:
    f.write(content)
