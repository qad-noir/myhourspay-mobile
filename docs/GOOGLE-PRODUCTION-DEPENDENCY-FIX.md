# Confirmed production Google failure

Production reference 0c86d329-6445-43ab-9114-c3d3dc0714bb identifies `Error: Class "Firebase\JWT\JWT" not found` in MobileIdentityVerifier.php line 26. The production Google exchange returned HTTP 500 even with an invalid diagnostic token. This is a missing/mismatched dependency deployment or autoloader, not evidence of a Google console or Android certificate failure.

The local Laravel composer.json already requires firebase/php-jwt ^7.2 and composer.lock pins v7.2.1. Deploy these matching files before running Composer in the production Laravel directory:

```sh
cd /home/raaingqv/mhp-app
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan config:clear
php artisan config:cache
php -r 'require "vendor/autoload.php"; echo class_exists("Firebase\\JWT\\JWT") ? "JWT available\n" : "JWT missing\n";'
```

Use the hosting CLI PHP version compatible with the application (composer.json requires PHP ^8.3). Do not ignore platform requirements or run a broad production composer update. If shell Composer is unavailable, deploy a complete vendor artifact generated from the matching lock file using compatible PHP, including vendor/composer autoload files; copying only the firebase directory is insufficient.

After the class check reports JWT available, retry Google sign-in on installed build 5. If another failure occurs, diagnose its new production reference separately. No successful live Google exchange has been claimed. Current APK can test this backend correction without a rebuild; consent wording changes are source-only until another APK is built.
