using BCrypt.Net;
var hash = BCrypt.Net.BCrypt.HashPassword("Admin@1234", BCrypt.Net.BCrypt.GenerateSalt(11));
Console.WriteLine(hash);
