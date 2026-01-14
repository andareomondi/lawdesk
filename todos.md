# LawDesk Development Roadmap

## Priority Legend
- [ ] Not Started
- [x] Completed
- [~] In Progress
- [!] Blocked/Issues

---

## TIER 1: CRITICAL - Must Have for MVP (Weeks 1-2)

### Core Case Management
- [x] **1. Create new case with basic details** (client name, case number, case type, date filed)
- [x] **2. Edit existing case details**
- [x] **3. Delete cases with confirmation dialog**
- [x] **4. View list of all cases** (sorted by date, searchable)
- [x] **5. Case status tracking** (Active, Pending, Closed, Won, Lost)
- [x] **6. Search cases** by client name, case number, or case type
- [x] **7. Filter cases** by status, date range, case type

### Client Management
- [x] **8. Add client profile** (name, contact, email, ID number)
- [x] **9. Link clients to cases** (one client can have multiple cases)
- [x] **10. View client details** with all associated cases
- [!] **11. Edit client information** The client edit feature is implemented but has bugs that need fixing.
- [x] **12. Search clients** by name or contact

### Document Management
- [x] **13. Attach documents to cases** (PDFs, images from phone)
- [x] **14. View attached documents** within the app
- [x] **15. Delete documents** from cases
- [x] **16. Organize documents by type** (pleadings, evidence, correspondence)

### Calendar & Events
- [x] **17. Add court dates/hearings** to calendar
- [x] **18. Set reminders** for upcoming hearings (24hr, 1 week before)
- [x] **19. View calendar with all events** (month/week view)
- [x] **20. Link events to specific cases**
- [x] **21. Mark events as completed**

---

## TIER 2: IMPORTANT - Core Features (Weeks 3-4)

### Enhanced Case Management
- [x] **22. Case notes/journal** (date-stamped notes for each case)
- [x] **23. Case timeline view** (chronological events)
- [ ] **24. Opposing counsel information** (name, firm, contact) I haven't found the logic behind this feature.
- [ ] **25. Case category tags** (family law, criminal, civil, corporate, etc) Next todo to work on.
- [!] **26. Case priority levels** (urgent, high, normal, low) Non existent priority level options.

### Task Management: ***None implemented yet***
- [ ] **27. Create tasks linked to cases** (research needed, file motions, etc)
- [ ] **28. Set task deadlines**
- [ ] **29. Mark tasks complete**
- [ ] **30. Task reminders/notifications**
- [ ] **31. View all tasks dashboard** (today, this week, overdue)

### Financial Tracking (Basic): ***None implemented yet. To be implemented with paying customers as a subscription option***
- [ ] **32. Log billable hours per case**
- [ ] **33. Set hourly rate**
- [ ] **34. View total billable amount per case**
- [ ] **35. Mark invoices as paid/unpaid**
- [ ] **36. Expense tracking per case** (court fees, filing costs)

### Communication
- [x] **37. Call client directly from app** (click phone number)
- [x] **38. Email client from app** (opens email client)
- [!] **39. SMS client from app** (opens SMS) Call and Email features are working and this is deemed less viable
- [ ] **40. Log communication history** (date, type, summary) Can't find the logic behind this feature.

---

## TIER 3: ENHANCED - Competitive Features (Weeks 5-8) ***None implemented yet***

### Advanced Features
- [ ] **41. Court location tracking** (save court addresses, get directions)
- [ ] **42. Witness management** (add witnesses to cases with contact info)
- [ ] **43. Evidence chain of custody tracking**
- [ ] **44. Case outcome prediction** based on similar cases (future AI feature)
- [ ] **45. Document templates** (motion templates, letter templates)
- [ ] **46. Bulk actions** (update multiple cases at once)
- [ ] **47. Case archiving** (move old cases to archive)

### Reporting & Analytics ***None implemented yet***
- [ ] **48. Generate case summary reports** (PDF export)
- [ ] **49. Monthly activity report** (cases opened, closed, court appearances)
- [ ] **50. Financial reports** (revenue by month, outstanding invoices)
- [ ] **51. Win/loss ratio tracking**
- [ ] **52. Case duration analytics** (average time to close)

### Collaboration (Multi-user) ***None implemented yet***
- [ ] **53. Share cases with colleagues** (view-only or edit access)
- [ ] **54. Internal case comments/discussions**
- [ ] **55. Assign tasks to team members**
- [ ] **56. Role-based permissions** (admin, advocate, paralegal)

### UX Improvements
- [ ] **57. Dark mode**
- [x] **58. Offline mode** (sync when online)
- [ ] **59. Data backup to cloud** (automatic)
- [ ] **60. Export all data** (for migration/backup)

---

## COMPETITIVE ANALYSIS GAPS TO FILL ***None implemented yet***

Based on competitors (Clio, MyCase, CaseFleet):

- [ ] **61. Voice notes for cases** (quick case updates via voice recording)
- [ ] **62. Statute of limitations tracker** (automatic deadline calculation)
- [ ] **63. Conflict of interest checker** (flag if client conflicts with existing clients)
- [ ] **64. Integration with court e-filing systems** (Kenya eCitizen integration?)
- [ ] **65. Client portal** (let clients view their case status via web)

---
