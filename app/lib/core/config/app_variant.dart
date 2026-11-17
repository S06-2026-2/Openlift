class AppVariant{
    AppVariant._();

    static const String value = String.fromEnvironment(
        'APP_VARIANT',
        defaultValue: 'A',
    );

    static bool get isB => value.toUpperCase() == 'B';
}