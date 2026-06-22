SELECT u."Username", u."BranchId", b."BranchCode", b."BranchName"
FROM "Users" u
LEFT JOIN "Branches" b ON b."Id" = u."BranchId"
WHERE u."Username" = 'admin';
