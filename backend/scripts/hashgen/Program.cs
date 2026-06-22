using BCrypt.Net;

var users = new[]
{
    ("manager1",    "Manager@1234"),
    ("accountant1", "Accountant@1234"),
    ("cashier1",    "Cashier@1234"),
    ("loanofficer1","LoanOfficer@1234"),
};

foreach (var (username, password) in users)
{
    var hash = BCrypt.Net.BCrypt.HashPassword(password, BCrypt.Net.BCrypt.GenerateSalt(11));
    Console.WriteLine($"{username}|{hash}");
}
