using System.Runtime.InteropServices;

// COM visibility for cross-platform compatibility
#if NET481 || (NET8_0 && WINDOWS)
[assembly: ComVisible(true)]
#else
[assembly: ComVisible(false)]
#endif

// GUID for COM
[assembly: Guid("7402F27D-79BB-44EA-92B4-B6492F74C6EC")]