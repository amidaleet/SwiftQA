/// Генерирует XCTestCase класс для снапшот тестов из структуры.
///
/// Функции с префиксом `test` и возвращаемым типом `SnapshotSut`, `UIView`, `UIViewController`, `SnapshotSutHolder` или `some View`
/// раскрываются в snapshot-тесты через `Snapshots.match`.
/// Unit-тесты в той же struct — только с `@UnitTest`.
///
/// Параметры по умолчанию задаются в `Snapshots.match`.
/// Любой параметр можно переопределить на уровне suite или отдельного теста через `@SnapshotTest`.
@attached(peer, names: suffixed(Host))
public macro SnapshotSuite(
    testName: String? = nil,
    matcher: SnapshotMatcherKind? = nil,
    mode: SnapshotMode? = nil,
    deviceGroup: SnapshotDeviceGroup? = nil,
    includeAccessibility: Bool = false
) = #externalMacro(module: "QASnapshotsMacros", type: "SnapshotSuiteMacro")

/// Кадр двойной ширины: обе темы сразу. Половины расставляет `theme`, вызов подставляет
/// макрос — в тестах темизацию не пишут.
@attached(peer, names: suffixed(Host))
public macro DualThemeSnapshotSuite<Theme: SnapshotThemeApplying>(
    theme: Theme.Type,
    testName: String? = nil,
    matcher: SnapshotMatcherKind? = nil,
    mode: SnapshotMode? = nil,
    deviceGroup: SnapshotDeviceGroup? = nil,
    includeAccessibility: Bool = false
) = #externalMacro(module: "QASnapshotsMacros", type: "SnapshotSuiteMacro")

/// Опциональный атрибут для переопределения параметров снапшот теста.
///
/// Параметры по умолчанию задаются в `Snapshots.match` и/или на уровне `@SnapshotSuite`.
@attached(peer)
public macro SnapshotTest(
    testName: String? = nil,
    matcher: SnapshotMatcherKind? = nil,
    mode: SnapshotMode? = nil,
    deviceGroup: SnapshotDeviceGroup? = nil,
    includeAccessibility: Bool = false
) = #externalMacro(module: "QASnapshotsMacros", type: "SnapshotTestMacro")

/// Маркер unit-теста внутри `@SnapshotSuite` / `@DualThemeSnapshotSuite`.
///
/// Без snapshot return type `test*`-функция не раскрывается в Host, пока не помечена `@UnitTest`.
@attached(peer)
public macro UnitTest() = #externalMacro(module: "QASnapshotsMacros", type: "UnitTestMacro")
