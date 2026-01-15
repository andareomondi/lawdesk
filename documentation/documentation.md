
---

# LawDesk Developer Documentation

## Index

* [Chapter 1: Project Introduction and Setup](#chapter-1-project-introduction-and-setup)
* [Chapter 2: Data Modeling](#chapter-2-data-modeling)
* [Chapter 3: Local Database Implementation](#chapter-3-local-database-implementation)
* [Chapter 4: Authentication Services](#chapter-4-authentication-services)
* [Chapter 5: Case Management Provider](#chapter-5-case-management-provider)
* [Chapter 6: User Interface - Case Forms](#chapter-6-user-interface---case-forms)
* [Chapter 7: Build and Deployment](#chapter-7-build-and-deployment)

---

## Chapter 1: Project Introduction and Setup

### Project Overview
LawDesk is a Flutter based android mobile application designed for managing and diarising legal cases. The app utilises supabase as its backend service for authentication and data storage. Notifications are handled through a custom cron job setup. 

The cron job initiates a serverless edge function which sends push notifications trigger to firebase cloud messaging which then delivers the notifications to the users devices which each has a specific fcm token.

***What is an FCM Token?***: It is a unique identifier assigned to each device by Firebase Cloud Messaging (FCM). This token allows the FCM service to route notifications specifically to that device. It also handles offline notifications by queuing them until the device is back online.

The application also handles document upload and storage using supabase storage buckets. View of documents is also possible using the [flutter_pdfview](https://pub.dev/packages/flutter_pdfview) package and the [photo_view](https://pub.dev/packages/photo_view) packages for pdf and Image views respectively.

Offline capabilities are provided through storing data locally using the [shared_preferences](https://pub.dev/packages/shared_preferences) package. This is not the most optimal solution for large data sets but works well for small scale usage. A better solution must be implemented in future versions using [sqlite](https://pub.dev/packages/sqlite) or hive databases.

OTA UPDATES: The app is capable of recieving over the air updates by using [shorebird_code_push](https://pub.dev/packages/shorebird_code_push) package. This allows for quick bug fixes and feature releases without going through the lengthy play store review process. ***Note: While building a patch for the app, ensure to use the code below to avoid issues with icon tree shaking which causes the app to crash on startup.***

```powershell
shorebird patch android '--' --no-tree-shake-icons

```
while for bash use
```bash
shorebird patch android -- --no-tree-shake-icons

```

Other packages used in the project include:
* [provider](https://pub.dev/packages/provider) - State Management
* [intl](https://pub.dev/packages/intl) - Date Formatting
* [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Network Connectivity Checks
* [delightful_toast](https://pub.dev/packages/delightful_toast) - Toast notifications
* [image_picker](https://pub.dev/packages/image_picker) - Image selection from gallery or camera
* [introduction_screen](https://pub.dev/packages/introduction_screen) - Onboarding screens
* [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) - App icon generation
* [liquid_pull_to_refresh](https://pub.dev/packages/liquid_pull_to_refresh) - Pull to refresh functionality
* [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) - Local notifications. ***Has been implemented but not yet in use. It's still buggy and unreliable. ***
* [Firebase_core](https://pub.dev/packages/firebase_core)
* [firebase_messaging](https://pub.dev/packages/firebase_messaging) - Firebase integration for push notifications.
* [url_launcher](https://pub.dev/packages/url_launcher) - To open contact information with relevant apps in the clients page.


### Establishing the Environment and Dependencies

This chapter covers the initial creation of the Flutter project and the installation of necessary dependencies required for case management, specifically state management, local storage, and unique identification.

### Implementation

#### 1. Create Flutter Project

Initialize a new Flutter project specifically targeting Android.

```bash
flutter create --org com.yourcompany case_manager_app
cd case_manager_app

```

#### 2. Dependency Injection

Add the required packages to the `pubspec.yaml` file. This includes `sqflite` for local storage, `provider` for state management, and `uuid` for generating unique case IDs.

```bash
flutter pub add sqflite path provider uuid intl

```

---

**Future Improvements:**

* Migrate to a specific Flutter version manager (FVM) to ensure team consistency.
* Set up Flavors (Dev, Staging, Prod) in the Gradle configuration.

---

## Chapter 2: Data Modeling

### Defining the Case Entity

This chapter details the structure of the `Case` object. It serves as the core data unit for the application, handling serialization and deserialization for database transactions.

### Implementation

#### 1. The Case Model Class

The primary class definition including properties for ID, title, description, status, and creation date.

```dart
class CaseModel {
  final String id;
  final String title;
  final String description;
  final String status; // e.g., 'Open', 'Pending', 'Closed'
  final DateTime dateCreated;

  CaseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dateCreated,
  });

  // Convert a Case into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'dateCreated': dateCreated.toIso8601String(),
    };
  }

  // Implement toString to make it easier to see information about
  // each case when using the print statement.
  @override
  String toString() {
    return 'Case{id: $id, title: $title, status: $status}';
  }
}

```

---

**Future Improvements:**

* Add strict TypeScript-style Enums for the `status` field instead of Strings.
* Implement `copyWith` methods to facilitate immutable state updates.

---

## Chapter 3: Local Database Implementation

### Persisting Data with SQLite

This chapter explains the setup of the SQLite database layer. It handles the creation of tables and the raw CRUD (Create, Read, Update, Delete) operations required for offline functionality.

### Implementation

#### 1. Database Initialization

This code opens the database and creates the `cases` table if it does not exist.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cases.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE cases ( 
  id $idType, 
  title $textType,
  description $textType,
  status $textType,
  dateCreated $textType
  )
''');
  }
}

```

#### 2. Insert Operation

A specific method to insert a new case into the database using conflict resolution.

```dart
Future<void> create(CaseModel caseItem) async {
  final db = await instance.database;
  
  await db.insert(
    'cases',
    caseItem.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

```

---

**Future Improvements:**

* Implement database migration scripts to handle schema changes in future app updates.
* Add encryption to the local database using SQLCipher for security compliance.

---

## Chapter 4: Authentication Services

### User Session Management

This chapter outlines the basic structure for handling user authentication. While currently mock-based, it establishes the interface for login and session token storage.

### Implementation

#### 1. Auth Service Interface

The base class defining the required methods for any authentication provider.

```dart
abstract class BaseAuthService {
  Future<bool> signIn(String email, String password);
  Future<void> signOut();
  Future<String?> getCurrentToken();
}

```

#### 2. Mock Implementation

A temporary implementation for development purposes to bypass backend requirements.

```dart
class MockAuthService implements BaseAuthService {
  @override
  Future<bool> signIn(String email, String password) async {
    // Simulate network delay
    await Future.delayed(Duration(seconds: 1));
    return (email.contains('@') && password.length > 5);
  }

  @override
  Future<void> signOut() async {
    print("User signed out");
  }

  @override
  Future<String?> getCurrentToken() async {
    return "mock_jwt_token_12345";
  }
}

```

---

**Future Improvements:**

* Integrate Firebase Auth or a custom REST API backend.
* Implement biometric authentication (Fingerprint/FaceID) for quicker login.

---

## Chapter 5: Case Management Provider

### State Management Logic

This chapter connects the UI to the Data Layer using the Provider pattern. It allows the UI to reactively update when cases are added or modified.

### Implementation

#### 1. The Cases Provider

This class extends `ChangeNotifier` to alert listeners (widgets) when the list of cases changes.

```dart
import 'package:flutter/material.dart';

class CaseProvider with ChangeNotifier {
  List<CaseModel> _items = [];

  List<CaseModel> get items {
    return [..._items];
  }

  void addCase(String title, String description) {
    final newCase = CaseModel(
      id: DateTime.now().toString(), // Replace with UUID in prod
      title: title,
      description: description,
      status: 'Open',
      dateCreated: DateTime.now(),
    );
    
    _items.add(newCase);
    // Notify widgets to rebuild
    notifyListeners();
    
    // Trigger DB save here
  }
  
  void deleteCase(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

```

---

**Future Improvements:**

* Implement lazy loading for the list to handle thousands of cases efficiently.
* Add sorting and filtering logic (e.g., Sort by Date, Filter by 'Open' status).

---

## Chapter 6: User Interface - Case Forms

### Input Handling and Validation

This chapter demonstrates the UI implementation for creating a new case, focusing on form validation and user input handling.

### Implementation

#### 1. New Case Form Widget

A Stateful widget containing a form with text validations.

```dart
import 'package:flutter/material.dart';

class NewCaseForm extends StatefulWidget {
  @override
  _NewCaseFormState createState() => _NewCaseFormState();
}

class _NewCaseFormState extends State<NewCaseForm> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';

  void _saveForm() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    
    _formKey.currentState!.save();
    // Call Provider to add case here
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Case Title'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a title';
              return null;
            },
            onSaved: (value) => _title = value!,
          ),
          ElevatedButton(
            onPressed: _saveForm,
            child: Text('Add Case'),
          ),
        ],
      ),
    );
  }
}

```

---

**Future Improvements:**

* Add file attachment capability (images/PDFs) to the form.
* Implement auto-save functionality to prevent data loss if the app crashes.

---

## Chapter 7: Build and Deployment

### Generating the Android Artifacts

This chapter covers the commands required to clean the project and generate a release APK or App Bundle for the Google Play Store.

### Implementation

#### 1. Clean Build Environment

Removes old build artifacts to ensure a fresh compilation.

```bash
flutter clean
flutter pub get

```

#### 2. Generate Release APK

Builds the fat APK for testing on generic Android devices.

```bash
flutter build apk --release

```

#### 3. Generate App Bundle

Builds the `.aab` file required for Play Store distribution.

```bash
flutter build appbundle --release

```

---

**Future Improvements:**

* Set up CI/CD pipelines (e.g., GitHub Actions or Codemagic) to automate builds on git push.
* Configure ProGuard rules to obfuscate code and reduce app size.

---

