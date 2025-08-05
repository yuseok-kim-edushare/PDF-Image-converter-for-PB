using System.Runtime.InteropServices;

// COM visibility - true for Windows (.NET 8), false for macOS (.NET 9)
#if NET8_0
[assembly: ComVisible(true)]
#else
[assembly: ComVisible(false)]
#endif

// GUID for COM
[assembly: Guid("7402F27D-79BB-44EA-92B4-B6492F74C6EC")]