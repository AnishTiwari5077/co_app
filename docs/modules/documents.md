# SahakariMS — Module: Documents

## Overview

The Documents module manages all KYC and supporting documents uploaded during member registration, loan applications, and other workflows. Documents are stored in MinIO (S3-compatible) and referenced by database records.

---

## Document Types

| Type | Required For | Retention |
|------|-------------|-----------|
| `CitizenshipFront` | Member registration | Permanent |
| `CitizenshipBack` | Member registration | Permanent |
| `PassportPhoto` | Member registration | Permanent |
| `SignaturePhoto` | Member registration | Permanent |
| `PanCard` | Loans > NPR 5L | 10 years |
| `IncomeProof` | Loan application | 10 years |
| `LandOwnership` | Land collateral | 10 years |
| `VehicleOwnership` | Vehicle collateral | 10 years |
| `GoldValuation` | Gold loan | 10 years |
| `LoanApplication` | Loan processing | 10 years |
| `LoanAgreement` | Loan disbursement | 10 years |
| `GuarantorCitizenship` | Guarantors | 10 years |
| `BoardResolution` | Institutional members | 10 years |

---

## Storage Structure (MinIO)

```
Bucket: sahakarims-documents
  /members/{memberId}/
    citizenship_front_{timestamp}.jpg
    citizenship_back_{timestamp}.jpg
    photo_{timestamp}.jpg
    signature_{timestamp}.png
  /loans/{loanId}/
    income_proof_{timestamp}.pdf
    land_ownership_{timestamp}.pdf
    loan_agreement_{timestamp}.pdf
  /vouchers/{voucherId}/
    supporting_doc_{timestamp}.pdf
```

---

## Upload Flow

```
POST /documents/upload (multipart/form-data)
Fields:
  file:          binary
  entityType:    Member | Loan | Voucher
  entityId:      UUID
  documentType:  CitizenshipFront | PanCard | etc.
  description:   Optional text

1. Validate file (type: jpg/png/pdf, size: max 5MB)
2. Virus scan (ClamAV)
3. Generate unique filename with timestamp
4. Upload to MinIO
5. Store metadata in DB
6. Return document ID + URL

Response 201:
{
  "id": "uuid",
  "documentType": "CitizenshipFront",
  "fileName": "citizenship_front_20240730_093211.jpg",
  "fileSize": 245678,
  "mimeType": "image/jpeg",
  "uploadedAt": "2081-04-15T09:32:11Z",
  "url": "/api/v1/documents/uuid"  // Signed URL served via API
}
```

---

## Document Service Implementation

```csharp
// Infrastructure/Documents/MinioDocumentService.cs
public class MinioDocumentService : IDocumentService
{
    private readonly IMinioClient _minio;
    private const string BucketName = "sahakarims-documents";
    private const long MaxFileSizeBytes = 5 * 1024 * 1024;  // 5MB

    private readonly HashSet<string> AllowedMimeTypes = new()
    {
        "image/jpeg", "image/png", "application/pdf"
    };

    public async Task<DocumentUploadResult> UploadAsync(
        DocumentUploadRequest request, CancellationToken ct)
    {
        // 1. Validate
        if (request.File.Length > MaxFileSizeBytes)
            throw new ValidationException("File size exceeds 5MB limit.");

        if (!AllowedMimeTypes.Contains(request.File.ContentType))
            throw new ValidationException("Only JPG, PNG, and PDF files are allowed.");

        // 2. Generate safe filename
        var extension = Path.GetExtension(request.File.FileName).ToLower();
        var fileName = $"{request.DocumentType.ToLower()}_{DateTime.UtcNow:yyyyMMdd_HHmmss}{extension}";
        var objectName = $"{request.EntityType.ToLower()}s/{request.EntityId}/{fileName}";

        // 3. Upload to MinIO
        using var stream = request.File.OpenReadStream();
        await _minio.PutObjectAsync(new PutObjectArgs()
            .WithBucket(BucketName)
            .WithObject(objectName)
            .WithStreamData(stream)
            .WithObjectSize(request.File.Length)
            .WithContentType(request.File.ContentType),
            ct);

        // 4. Save metadata to DB
        var document = new Document
        {
            EntityType = request.EntityType,
            EntityId = request.EntityId,
            DocumentType = request.DocumentType,
            FileName = fileName,
            ObjectPath = objectName,
            FileSize = request.File.Length,
            MimeType = request.File.ContentType,
            UploadedBy = request.UploadedBy
        };

        await _documentRepo.CreateAsync(document, ct);

        return new DocumentUploadResult(document.Id, fileName, objectName);
    }

    public async Task<Stream> DownloadAsync(Guid documentId, Guid requestingUserId, CancellationToken ct)
    {
        var document = await _documentRepo.GetByIdAsync(documentId, ct)
            ?? throw new NotFoundException($"Document {documentId} not found.");

        // Verify access rights
        await _authorizationService.AuthorizeDocumentAccessAsync(
            requestingUserId, document, ct);

        // Generate pre-signed URL (valid for 15 minutes) or stream directly
        var memoryStream = new MemoryStream();
        await _minio.GetObjectAsync(new GetObjectArgs()
            .WithBucket(BucketName)
            .WithObject(document.ObjectPath)
            .WithCallbackStream(stream => stream.CopyTo(memoryStream)),
            ct);

        memoryStream.Position = 0;
        return memoryStream;
    }
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| POST | `/documents/upload` | Based on entity | Upload document |
| GET | `/documents/{id}` | Based on entity | Download/view document |
| GET | `/documents?entityType=Member&entityId=uuid` | Based on entity | List entity's docs |
| DELETE | `/documents/{id}` | ADMIN | Delete document (audit trail kept) |
| GET | `/documents/{id}/metadata` | Based on entity | File metadata only |

---

## Document Viewer (Flutter)

```dart
// lib/shared/widgets/document_viewer.dart
class DocumentViewer extends StatelessWidget {
  final String documentId;
  final DocumentType type;

  @override
  Widget build(BuildContext context) {
    // PDF files — flutter_pdfview
    if (type.isPdf) {
      return PdfDocumentViewer(documentId: documentId);
    }
    // Images — cached_network_image with auth headers
    return AuthenticatedImage(documentId: documentId);
  }
}
```
