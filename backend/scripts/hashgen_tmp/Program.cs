using BCrypt.Net;
var users = new[]
{
    ("admin",        "Admin@1234"),
    ("manager1",     "Manager@1234"),
    ("accountant1",  "Accountant@1234"),
    ("cashier1",     "Cashier@1234"),
    ("loanofficer1", "LoanOfficer@1234"),
};
foreach (var (u, p) in users)
{
    var hash = BCrypt.Net.BCrypt.HashPassword(p, BCrypt.Net.BCrypt.GenerateSalt(11));
    System.Console.WriteLine($"{u}|{hash}");
}
