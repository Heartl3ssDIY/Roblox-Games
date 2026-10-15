# Course 1 loading screen

Installed in Gameplay (Course 1), place 128350578096458.

Editable frame: ReplicatedFirst > GBloxCourseLoading > GBloxCourseLoadingScreen > Root > LoadingScreen.

Uses the main place's loading artwork, percentage bar, title gloss and sound toggle. There is no MainScreen, Play, Shop or Settings menu. At 100%, the loading screen fades out automatically over 0.65 seconds and enables movement.

LoadingConfig includes the six UI images, two sound effects and 21 distinct course assets found during installation. Update CourseAssets when adding assets in distant streamed parts of the course. The loader retries failed downloads and offers Retry instead of falsely reporting 100%.

GBloxCourseLoadingGate holds the character at spawn until loading and the fade finish. Respawning after the initial load does not show the loading screen again.

All three scripts compiled. Studio tests reached 100%, entered gameplay, released the character, and confirmed the loading screen stays closed after respawning. No loading errors appeared in the final game output.

Changes are in the open Studio place and are not published to the live experience. Files here are source backups.
