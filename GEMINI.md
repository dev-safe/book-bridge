# Gemini CLI Context for BookBridge

This document provides instructional context for interacting with the BookBridge project.

## Project Overview

BookBridge is a mobile application built with **Flutter** that serves as a peer-to-peer marketplace for students in Cameroon to buy and sell used physical books. The backend is powered by **Supabase**, handling user authentication and the database of book listings.

The project follows a **Clean Architecture** pattern, separating concerns into `Domain`, `Data`, and `Presentation` layers.

Additionally, there is a `landingPage` directory containing a separate web project built with **SvelteKit** and **Vite**, presumably for marketing or as a web front-end for the service.

### Key Technologies

- **Mobile App (Flutter):**
  - **State Management:** `provider` with `ChangeNotifier`
  - **Navigation:** `go_router`
  - **Dependency Injection:** `get_it`
  - **Backend Integration:** `supabase_flutter`
  - **Error Handling:** `dartz` for functional error handling (`Either`)
- **Landing Page (Web):**
  - **Framework:** SvelteKit
  - **Build Tool:** Vite
- **Backend:**
  - Supabase (Auth, PostgreSQL Database, Storage)

## Building and Running

### Flutter Mobile App

1.  **Install Dependencies:**

    ```bash
    flutter pub get
    ```

2.  **Configure Environment:**
    Create a `.env` file in the project root. You can copy the example:

    ```bash
    cp .env.example .env
    ```

    Then, fill in your Supabase project credentials in the `.env` file:

    ```
    SUPABASE_URL=your_supabase_project_url
    SUPABASE_ANON_KEY=your_supabase_anon_key
    ```

3.  **Run the App:**
    Use the `--dart-define` flags to pass the environment variables from the `.env` file to the Flutter app.
    ```bash
    flutter run \
      --dart-define="SUPABASE_URL=$(grep SUPABASE_URL .env | cut -d'=' -f2)" \
      --dart-define="SUPABASE_ANON_KEY=$(grep SUPABASE_ANON_KEY .env | cut -d'=' -f2)" \
      --dart-define="GOOGLE_CLIENT_ID=$(grep GOOGLE_CLIENT_ID .env | cut -d'=' -f2)"
    ```

    Fapshi credentials are not passed to the app; payments go through the Rust core service.

### SvelteKit Landing Page

1.  **Navigate to Directory:**

    ```bash
    cd landingPage
    ```

2.  **Install Dependencies:**

    ```bash
    npm install
    ```

3.  **Run the Development Server:**
    ```bash
    npm run dev
    ```

## Development Conventions

- **Architecture:** The codebase is structured using Clean Architecture principles. When adding new features, create or modify files within the `lib/features` directory, respecting the `domain`, `data`, and `presentation` layers.
- **Code Quality:** Maintain high code quality by using the standard Dart/Flutter tools. Before committing, it's good practice to run:
  - `flutter analyze` - To check for any static analysis issues.
  - `dart format .` - To ensure consistent code formatting.
- **State Management:** App state is managed using the `provider` package. For new UI features requiring state, create a `ChangeNotifier` and provide it to the relevant widget tree.
- **Navigation:** All routing is handled by `go_router`. Add new routes or modify existing ones in `lib/config/router.dart`.
