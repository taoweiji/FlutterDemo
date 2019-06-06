#!/usr/bin/env bash
# publish_android_aar.sh

# 我们用于打包aar的module名称
myFlutterModule="myflutter"


echo "Clean old build"
find . -d -name "build" | xargs rm -rf
flutter clean

echo "Get packages"
flutter packages get

# 复制插件生成的GeneratedPluginRegistrant.java到我们需要打包的module
echo 'Copy GeneratedPluginRegistrant.java to module'
mkdir -p android/${myFlutterModule}/src/main/java/io/flutter/plugins && cp android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java "$_"

# 将依赖的插件打包发布到本地或者远程的maven仓库，需要修改android/build.gradle
echo 'Build and publish module to repo'
cd android
gradlewScript=""
file="../.flutter-plugins"
while read line
do
    array=(${line//=/ })
    moduleName=${array[0]}
    gradlewScript="$gradlewScript:${moduleName}:clean :${moduleName}:uploadArchives "
done < ${file}
gradlewScript=${gradlewScript}":${myFlutterModule}:clean :${myFlutterModule}:uploadArchives "
echo "./gradlew ${gradlewScript}"
./gradlew ${gradlewScript}
