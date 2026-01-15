
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
* [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) - Local notifications have been implemented but not yet in use. It's still buggy and unreliable. 
* [Firebase_core](https://pub.dev/packages/firebase_core) - Core firebase functionalities.
* [firebase_messaging](https://pub.dev/packages/firebase_messaging) - Firebase integration for push notifications.
* [url_launcher](https://pub.dev/packages/url_launcher) - To open contact information with relevant apps in the clients page.


### Establishing the Environment and Dependencies

This chapter outlines the initial setup required to get the development environment ready for building the LawDesk application. It includes project creation, dependency management, and configuration steps.
Kindly follow the steps shown in the [README.md](https://github.com/andareomondi/lawdesk/blob/main/README.md) file of the project. This does not include setting up the supabase backend. This will be show in a future chapter.

**Future Improvements:**

* Migrate to a specific Flutter version manager (FVM) to ensure team consistency.
* Set up Flavors (Dev, Staging, Prod) in the Gradle configuration.

---

## Chapter 2: Data Modeling

### Defining the Case Entity

This chapter details the structure of the `Case` object. It serves as the core data unit for the application in which everything else is build around.

### Implementation

#### 1. The Case Model Class

This is the sql representation of a legal case in the application. It includeds fields for id, created_at, name, number, status, description, courtDate, court_name, time, progress_status and user. The fields `name` and  `user` are foreign keys linked to the clients and users tables respectively.

```sql

create table public.cases (
  id bigint generated by default as identity not null,
  created_at timestamp with time zone not null default now(),
  name text null,
  number text null,
  court_name text null,
  status text null,
  "courtDate" date null,
  time time without time zone null,
  description text null,
  "user" uuid null,
  progress_status boolean null default false,
  constraint cases_pkey primary key (id),
  constraint cases_name_fkey foreign KEY (name) references clients (name) on delete CASCADE,
  constraint cases_user_fkey foreign KEY ("user") references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

```
***Note1:*** The fields `status` and `progress_status` are used to track the state of the case. `status` is a string that can hold values like 'Urgent', 'No worries', 'Upcoming', etc. in respective to the court date and the days date, while `progress_status` is a boolean indicating whether the case is actively being worked on.

***Note2:*** The field `courtDate` is of type date which only stores the date without the time component. The field `time` is used to store the specific time of the court hearing.

***Note3:*** The field `user` is a foreign key that references the `id` field in the `auth.users` table. This links each case to a specific user account.

***Note4:*** The field `name` is a foreign key that references the `name` field in the `clients` table. This links each case to a specific client.

***Note5:*** Cascade delete is enabled on both foreign keys to ensure that when a user or client is deleted, all associated cases are also removed from the database.


---

**Future Improvements:**

* Add indexing on frequently queried fields like `status` and `courtDate` to improve query performance.
* Implement data validation logic within the model to ensure data integrity.
* Implement a better `status` tracking mechanism.
##### ***MUST:*** Implement a billing mechanism to track billable hours per case.


### Defining of other Entities and tables
Other important entities such as `Client`, `Document`, `Events`, `Profiles` and `Court` sql representation are as follows:

***Clients Table:***
``` sql

create table public.clients (
  id bigint generated by default as identity not null,
  created_at timestamp with time zone not null default now(),
  name text null,
  email text null,
  notes text null,
  phone integer null,
  "user" uuid null,
  constraint clients_pkey primary key (id),
  constraint clients_name_key unique (name),
  constraint clients_user_fkey foreign KEY ("user") references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

```
***Documents Table:***
``` sql
create table public.documents (
  id uuid not null default gen_random_uuid (),
  case_id integer not null,
  uploaded_by uuid null,
  file_name text not null,
  file_path text not null,
  file_size integer null,
  mime_type text null,
  document_type text null,
  bucket_name text null default 'case_documents'::text,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  public_url text null,
  constraint documents_pkey primary key (id),
  constraint documents_case_id_fkey foreign KEY (case_id) references cases (id) on delete CASCADE,
  constraint documents_uploaded_by_fkey foreign KEY (uploaded_by) references auth.users (id)
) TABLESPACE pg_default;

create trigger on_document_delete_remove_storage BEFORE DELETE on documents for EACH row
execute FUNCTION delete_document_storage ();

```
***Events Table:***
``` sql

create table public.events (
  id bigint generated by default as identity not null,
  created_at timestamp with time zone not null default now(),
  agenda text null,
  date date null,
  time time without time zone null,
  "case" bigint null,
  profile uuid null,
  constraint events_pkey primary key (id),
  constraint events_case_fkey foreign KEY ("case") references cases (id) on delete CASCADE,
  constraint events_profile_fkey foreign KEY (profile) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

```
***Profiles Table:***
``` sql

create table public.profiles (
  id uuid not null,
  updated_at timestamp with time zone null,
  username text null,
  full_name text null,
  gender text null,
  email text null,
  is_admin boolean null,
  is_updated boolean null default false,
  lsk_number text null,
  fcm_token text null,
  constraint profiles_pkey primary key (id),
  constraint profiles_lsk_number_key unique (lsk_number),
  constraint profiles_username_key unique (username),
  constraint profiles_id_fkey foreign KEY (id) references auth.users (id) on delete CASCADE,
  constraint username_length check ((char_length(username) >= 3))
) TABLESPACE pg_default;

```
***Courts Table:***
``` sql

create table public.court (
  id bigint generated by default as identity not null,
  created_at timestamp with time zone not null default now(),
  name text null,
  constraint court_pkey primary key (id),
  constraint court_name_key unique (name)
) TABLESPACE pg_default;

```

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

