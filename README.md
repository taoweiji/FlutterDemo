# 在Android项目中加入Flutter，部分功能使用Flutter混合开发方案
https://www.jianshu.com/p/a71ec6471a06
我们在尝试Flutter的时候，其实可以在我们现成的项目中加入Flutter，然后改造我们部分不是特别重要的的功能，避免引发较大的风险，也可以把新技术引入进来。在React Native的时候，我们也尝试做过类似的方案，后来基于稳定性和维护成本，最终换回了原生开发。

##### 谁在用Flutter混合开发？
闲鱼APP就是典型的原生&Flutter开发方案，通过Android的“显示布局边界”工具，可以看到，闲鱼APP的商品详情页、游戏交易区、短租交易区都已经是使用Flutter改造。

![](https://upload-images.jianshu.io/upload_images/2431302-8e8054d4c105ff76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



##### 分析增加包体积的成本分析（增加5.1MB）
通过分析生成的正式apk包，我们可以看到，Flutter的实现主要是C++实现，这里会增加3.5MB大小，另外就是assets文件夹，这里会增加1.6 MB，由于Flutter增加的jar代码很少，可以忽略不计。从中分析，项目中如果加入Flutter，会增加5.1MB的大小左右，这个大小还是非常可观，不算大。

![](https://upload-images.jianshu.io/upload_images/2431302-bc2e8e4bb03f938a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

- isolate_snapshot_data 应用程序数据段
- isolate_snapshot_instr 应用程序指令段
- vm_snapshot_data VM虚拟机数据段
- vm_snapshot_instr VM虚拟机指令段
##### Flutter依赖原理分析
我们通过默认生成的android项目的build.gradle文件可以看到，其实在我们现成的项目中加入flutter的支持是非常简单的，核心就是flutter.gradle，在flutter的安装包中flutter/packages/flutter_tools/gradle可以看到这个文件。
```
apply plugin: 'com.android.application'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
```
[packages/flutter_tools/gradle/flutter.gradle](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/gradle/flutter.gradle)
这个文件的作用主要是：
1. 增加 flutter.jar和so依赖。
2. Flutter Plugin编译依赖插件。
3. 插入工程编译产物，就是assets目录下的内容，isolate_snapshot_data和vm_snapshot_data。

##### 在现成项目引入Flutter，基础版本教程
由于开发Flutter是需要配置Flutter的环境，在实际的团队当中，并不是所有成员都必须参与到Flutter开发中，非Flutter开发人员也不应该需要配置Flutter开发环境，所以我们只需要将需要的代码引入进来，非Flutter开发人员就不需要配置环境，所以我们只需要复制flutter.jar和libflutter.so和assets文件到我们项目即可。

```
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
```
创建一个Activity承载Flutter
```
public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
  }
}

```

##### 在现成项目引入Flutter，升级版本教程
从上面的基础教程，我们其实就已经可以实现在现有的项目中使用Flutter，但是每次都需要复制文件到指定目录，其实我们可以换个方式来实现，就是通过依赖管理实现，我们将flutter.jar和libflutter.so文件，还有assets里面的编译产物一起打包生成aar，然后上传到maven仓库，我们主工程就可以非常简单地通过依赖方式引入，丝毫不会污染原来的工程代码，Flutter开发和原生开发就可以进行了隔离，后续会补充这部分的教程。
```
dependencies {
    implementation 'com.taoweiji.flutter:aboutme:1.0.0'
}
```
创建一个Activity承载Flutter
```
public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
  }
}

```

## 教程
##### 创建android module
在android目录下的app是flutter默认的运行宿主，如果我们需要打包成一个aar，那么我们需要创建一个module来承载，这个module最重要的地方是build.gradle，这个文件的内容复制android/app/build.gradle目录下的文件，把 `apply plugin: 'com.android.application'` 改成`apply plugin: 'com.android.library'`，并增加`group`和`version`的定义。
```
//build.gradle
apply plugin: 'com.android.library'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
...略去几十行代码
group = 'com.taoweiji.flutter'
version = '1.0.0-SNAPSHOT'
```
##### 配置Maven上传
发布aar有两种，一个是本地发布，一个是搭建Maven服务器来实现，我们需要修改android/build.gradle文件

```gradle
buildscript {
    repositories {
        google()
        jcenter()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:3.4.1'
        classpath 'com.github.dcendents:android-maven-gradle-plugin:2.1'
    }
}
...
subprojects {
    apply plugin: 'maven'
    uploadArchives {
        repositories {
            mavenDeployer {
                repository(url: uri('/Users/Wiki/repo'))// 填写本地的仓库地址
                //repository(url: "https://oss.sonatype.org/service/local/staging/deploy/maven2/") {
                //    authentication(userName: ossrhUsername, password: ossrhPassword)
                //}
            }
        }
    }
}
```
##### 编写打包发布脚本
在flutter的项目根目录创建一个脚本文件 publish_android_aar.sh
```
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
```
##### 指定打包命令
在命令行中执行命令，即可发布aar
```
sh publish_android_aar.sh
```

### 在现成的项目中使用
##### 引入本地仓库
修改项目根目录的build.gradle
```
buildscript {
    repositories {
        maven {
            url uri('/Users/Wiki/repo')//填写本地的仓库地址
        }
    }
}
```
##### 引入应用
修改app目录的build.gradle
```
dependencies {
    implementation "com.taoweiji.flutter:myflutter:1.0.1-SNAPSHOT"
}
```

##### 创建一个Activity
我们需要创建一个Activity来承载Flutter的入口，记得在AndroidManifest.xml配置哦

```
public class MyFlutterActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // 初始化Flutter
        FlutterMain.startInitialization(getApplicationContext());
        super.onCreate(savedInstanceState);
        GeneratedPluginRegistrant.registerWith(this);
    }
}
```
到这里就大功告成了，Flutter开发和原生开发分割开，通过maven方式引入。

#### 完整源代码
[https://github.com/taoweiji/FlutterDemo](https://github.com/taoweiji/FlutterDemo)

##### 附加
[Flutter 与 Android 相互调用、传递参数](https://www.jianshu.com/p/440e4132fe21)

[Flutter 初尝试：入门教程](https://www.jianshu.com/p/e889c5d407a9)

[Flutter 安装教程](https://www.jianshu.com/p/42890fe457f1)






