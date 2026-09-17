# Monetix Flutter Release Checklist

This guide provides a standardized, operational checklist to ensure every single package release on [pub.dev](https://pub.dev) is issued with absolute precision, safety, and correct version alignment.

---

## 🛠️ Step 1: Pre-Release Verification

Before modifying any version files, ensure the codebase is structurally complete.

- [ ] **Check active branch**: Ensure you are on the `main` branch and have pulled all remote changes.
- [ ] **Run local verification**:
  ```bash
  flutter pub get
  flutter analyze
  flutter test
  ```
- [ ] **Run publishing dry-run**: Ensure there are no warnings or packaging errors.
  ```bash
  flutter pub publish --dry-run
  ```

---

## 🤖 LLM & Contributor Resiliency Guidelines

> [!WARNING]
> To any LLM (like Claude or Gemini) or contributor processing a release, pub.dev enforces **extremely strict** validation that CI runners will fail on if you miss these details:
> 
> 1. **Zero Analyzer Tolerance**: `flutter pub publish` will fail if there is even a single `info` level log (like a deprecation warning).
> 2. **Latest Dependency Trap**: CI runners fetch the *absolute latest* dependencies matching `pubspec.yaml` constraints. Your local workspace might not have them. ALWAYS run `flutter pub upgrade` before `flutter analyze` to ensure you are catching the same deprecation warnings the CI runner will see!
> 3. **Backward Compatibility First**: If a dependency update deprecates a method, DO NOT immediately refactor to the new method unless you are forcing a major breaking change. Refactoring to a new method will break the package for users on older versions of that dependency. Instead, use `// ignore: deprecated_member_use` to satisfy the analyzer while maintaining backward compatibility.
> 4. **CHANGELOG Strictness**: The `CHANGELOG.md` **MUST** explicitly contain a header for the exact version number being pushed. Pub.dev will flag a validation error if the version in `pubspec.yaml` does not exist in `CHANGELOG.md`.

---

## 📝 Step 2: Versioning & Documentation

> [!IMPORTANT]
> The version declared in `pubspec.yaml` **must exactly match** the git tag pushed to GitHub. Mismatched tags will result in automatic publish rejection on pub.dev.

- [ ] **Update `pubspec.yaml`**: Update the `version` field (e.g. `version: 0.1.5`).
- [ ] **Update `README.md`**: Update the installation instructions version reference to reflect the new release.
- [ ] **Update `CHANGELOG.md`**:
  - Add a new `## X.Y.Z` header at the very top of the file.
  - Document all features, bug fixes, breaking changes, and internal optimizations clearly in bullet points.

---

## 🚀 Step 3: Git Tagging & Publish Triggering

> [!TIP]
> Do not manually run `flutter pub publish`! Our automated GitHub Actions workflow will perform verification and securely publish the package once you push the tag.

- [ ] **Stage & commit files**:
  ```bash
  git add .
  git commit -m "chore: release version X.Y.Z"
  ```
- [ ] **Create git tag**: Make sure the tag has a prefix of `v` followed by the exact version (e.g. `v0.1.5`).
  ```bash
  git tag vX.Y.Z
  ```
- [ ] **Push commit and tag to origin**:
  ```bash
  git push origin main
  git push origin vX.Y.Z
  ```

---

## 📡 Step 4: Release Pipeline Monitoring

- [ ] **Monitor GitHub Actions**: Go to the **Actions** tab of your repository and ensure the `Publish to pub.dev` workflow starts, passes all analysis, runs tests, and completes successfully.
- [ ] **Verify on pub.dev**: Once the workflow finishes, verify that the new version is live on [pub.dev/packages/monetix_flutter](https://pub.dev/packages/monetix_flutter).
