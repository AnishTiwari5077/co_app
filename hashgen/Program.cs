using System;
using BCrypt.Net;
var hash = BCrypt.Net.BCrypt.HashPassword("Admin@1234", workFactor: 11);
Console.WriteLine(hash);
