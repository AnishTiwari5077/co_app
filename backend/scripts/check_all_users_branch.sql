-- Check all users and their branch assignments
SELECT u."Username", u."BranchId", b."BranchCode", b."BranchName" 
FROM "Users" u 
LEFT JOIN "Branches" b ON b."Id" = u."BranchId" 
ORDER BY u."CreatedAt";
