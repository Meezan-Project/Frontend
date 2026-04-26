import 'package:mezaan/user/models/case_model.dart';

class MockCaseData {
  static List<UserCase> getMockCases() {
    return [
      UserCase(
        id: 'case_001',
        caseNumber: 'CASE-2024-001',
        title: 'Property Dispute - Residential Building',
        description:
            'Resolving ownership dispute over residential property in downtown area. Complex case involving multiple stakeholders and title verification.',
        lawyerId: 'lawyer_001',
        lawyerName: 'Ahmed El-Masry',
        lawyerAvatar: null,
        status: 'active',
        category: 'Real Estate',
        createdDate: DateTime.now().subtract(const Duration(days: 120)),
        closedDate: null,
        sessions: [
          CaseSession(
            id: 'session_1',
            scheduledDate: DateTime.now().add(const Duration(days: 7)),
            location: 'Court Building A, Room 205',
            notes: 'Initial hearing with all parties present',
            status: 'scheduled',
          ),
          CaseSession(
            id: 'session_2',
            scheduledDate: DateTime.now().subtract(const Duration(days: 14)),
            location: 'Lawyer Office, Downtown Branch',
            notes: 'Document review meeting',
            result: 'All documents verified and authenticated successfully',
            status: 'completed',
          ),
        ],
        requiredDocuments: [
          RequiredDocument(
            id: 'doc_1',
            name: 'Property Deed',
            description: 'Original property deed and ownership documents',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 100)),
          ),
          RequiredDocument(
            id: 'doc_2',
            name: 'Government ID',
            description: 'Valid government-issued identification',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 98)),
          ),
          RequiredDocument(
            id: 'doc_3',
            name: 'Previous Contract',
            description: 'Original purchase contract and agreements',
            isSubmitted: false,
          ),
          RequiredDocument(
            id: 'doc_4',
            name: 'Bank Statements',
            description: 'Bank transfer records and payment proof',
            isSubmitted: false,
          ),
        ],
        updates: [
          CaseUpdate(
            id: 'update_1',
            date: DateTime.now().subtract(const Duration(days: 5)),
            title: 'Next Hearing Scheduled',
            description:
                'The next hearing has been scheduled for next week. Please ensure all documents are ready.',
            type: 'action',
          ),
          CaseUpdate(
            id: 'update_2',
            date: DateTime.now().subtract(const Duration(days: 14)),
            title: 'Document Verification Completed',
            description:
                'All submitted documents have been verified and authenticated by the court.',
            type: 'process',
          ),
          CaseUpdate(
            id: 'update_3',
            date: DateTime.now().subtract(const Duration(days: 25)),
            title: 'Case Accepted',
            description:
                'Your case has been accepted and assigned to the legal team.',
            type: 'result',
          ),
        ],
        notes:
            'High priority case. Client needs resolution within 6 months. All parties cooperative.',
      ),
      UserCase(
        id: 'case_002',
        caseNumber: 'CASE-2024-002',
        title: 'Employment Dispute - Wrongful Termination',
        description:
            'Client was terminated without proper notice. Seeking compensation and reinstatement. Documentation available.',
        lawyerId: 'lawyer_002',
        lawyerName: 'Fatima Al-Rashid',
        lawyerAvatar: null,
        status: 'pending',
        category: 'Labor Law',
        createdDate: DateTime.now().subtract(const Duration(days: 45)),
        closedDate: null,
        sessions: [
          CaseSession(
            id: 'session_1',
            scheduledDate: DateTime.now().add(const Duration(days: 14)),
            location: 'Labor Court, Building B',
            notes: 'First hearing and case presentation',
            status: 'scheduled',
          ),
        ],
        requiredDocuments: [
          RequiredDocument(
            id: 'doc_1',
            name: 'Employment Contract',
            description: 'Original employment contract and amendments',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 40)),
          ),
          RequiredDocument(
            id: 'doc_2',
            name: 'Termination Letter',
            description: 'Official termination letter from employer',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 40)),
          ),
          RequiredDocument(
            id: 'doc_3',
            name: 'Salary Records',
            description: 'Last 12 months salary and payment records',
            isSubmitted: false,
          ),
        ],
        updates: [
          CaseUpdate(
            id: 'update_1',
            date: DateTime.now().subtract(const Duration(days: 2)),
            title: 'Case Documents Submitted',
            description:
                'All initial case documents have been submitted to the labor court.',
            type: 'action',
          ),
          CaseUpdate(
            id: 'update_2',
            date: DateTime.now().subtract(const Duration(days: 10)),
            title: 'Case Filing Initiated',
            description: 'The case has been filed with the labor department.',
            type: 'process',
          ),
        ],
        notes: 'Client has strong evidence. First hearing scheduled for next month.',
      ),
      UserCase(
        id: 'case_003',
        caseNumber: 'CASE-2024-003',
        title: 'Inheritance Settlement - Family Property',
        description:
            'Inheritance dispute involving family property distribution. Requires mediation between heirs.',
        lawyerId: 'lawyer_001',
        lawyerName: 'Ahmed El-Masry',
        lawyerAvatar: null,
        status: 'on_hold',
        category: 'Family Law',
        createdDate: DateTime.now().subtract(const Duration(days: 90)),
        closedDate: null,
        sessions: [
          CaseSession(
            id: 'session_1',
            scheduledDate: DateTime.now().subtract(const Duration(days: 30)),
            location: 'Mediation Center',
            notes: 'Mediation session with family members',
            result: 'Parties agreed to extend negotiation period by 30 days',
            status: 'completed',
          ),
        ],
        requiredDocuments: [
          RequiredDocument(
            id: 'doc_1',
            name: 'Will Document',
            description: 'Official will and testament',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 85)),
          ),
          RequiredDocument(
            id: 'doc_2',
            name: 'Death Certificate',
            description: 'Official death certificate',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 85)),
          ),
          RequiredDocument(
            id: 'doc_3',
            name: 'Property Assessment',
            description: 'Professional property valuation report',
            isSubmitted: false,
          ),
        ],
        updates: [
          CaseUpdate(
            id: 'update_1',
            date: DateTime.now().subtract(const Duration(days: 30)),
            title: 'Case On Hold - Mediation in Progress',
            description:
                'Case temporarily on hold while family members attempt mediation.',
            type: 'general',
          ),
        ],
        notes: 'Awaiting family decision. Case will resume next month.',
      ),
      UserCase(
        id: 'case_004',
        caseNumber: 'CASE-2024-004',
        title: 'Contract Breach - Commercial Agreement',
        description:
            'Vendor failed to deliver services as per contract. Seeking compensation for losses.',
        lawyerId: 'lawyer_003',
        lawyerName: 'Mohammed Hassan',
        lawyerAvatar: null,
        status: 'closed',
        category: 'Commercial Law',
        createdDate: DateTime.now().subtract(const Duration(days: 180)),
        closedDate: DateTime.now().subtract(const Duration(days: 10)),
        sessions: [
          CaseSession(
            id: 'session_1',
            scheduledDate: DateTime.now().subtract(const Duration(days: 20)),
            location: 'Court Building A, Main Hall',
            notes: 'Final judgment hearing',
            result:
                'Court ruled in favor of plaintiff. Defendant ordered to pay full compensation.',
            status: 'completed',
          ),
          CaseSession(
            id: 'session_2',
            scheduledDate: DateTime.now().subtract(const Duration(days: 50)),
            location: 'Court Building A, Room 310',
            notes: 'Evidence presentation and witness testimony',
            result: 'All evidence accepted and documented',
            status: 'completed',
          ),
        ],
        requiredDocuments: [
          RequiredDocument(
            id: 'doc_1',
            name: 'Contract Agreement',
            description: 'Original signed contract',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 175)),
          ),
          RequiredDocument(
            id: 'doc_2',
            name: 'Correspondence Records',
            description: 'Email and communication records with vendor',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 175)),
          ),
          RequiredDocument(
            id: 'doc_3',
            name: 'Damage Assessment',
            description: 'Financial impact report',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 160)),
          ),
        ],
        updates: [
          CaseUpdate(
            id: 'update_1',
            date: DateTime.now().subtract(const Duration(days: 10)),
            title: 'Case Closed - Victory',
            description:
                'Case successfully closed. Court judgment in favor of client.',
            type: 'result',
          ),
          CaseUpdate(
            id: 'update_2',
            date: DateTime.now().subtract(const Duration(days: 20)),
            title: 'Final Judgment Delivered',
            description: 'Judge issued final ruling and compensation amount.',
            type: 'result',
          ),
        ],
        notes: 'Case successfully resolved. Compensation to be paid within 30 days.',
      ),
      UserCase(
        id: 'case_005',
        caseNumber: 'CASE-2024-005',
        title: 'Trademark Infringement - Brand Protection',
        description:
            'Competitor using similar brand name. Action needed to protect intellectual property.',
        lawyerId: 'lawyer_002',
        lawyerName: 'Fatima Al-Rashid',
        lawyerAvatar: null,
        status: 'active',
        category: 'Intellectual Property',
        createdDate: DateTime.now().subtract(const Duration(days: 60)),
        closedDate: null,
        sessions: [
          CaseSession(
            id: 'session_1',
            scheduledDate: DateTime.now().add(const Duration(days: 21)),
            location: 'IP Court, Building C',
            notes: 'Trademark hearing and injunction request',
            status: 'scheduled',
          ),
        ],
        requiredDocuments: [
          RequiredDocument(
            id: 'doc_1',
            name: 'Trademark Registration',
            description: 'Official trademark registration certificate',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 55)),
          ),
          RequiredDocument(
            id: 'doc_2',
            name: 'Evidence of Use',
            description: 'Documentation showing continuous use of trademark',
            isSubmitted: true,
            submittedDate: DateTime.now().subtract(const Duration(days: 55)),
          ),
          RequiredDocument(
            id: 'doc_3',
            name: 'Market Impact Report',
            description: 'Analysis of market confusion and damages',
            isSubmitted: false,
          ),
        ],
        updates: [
          CaseUpdate(
            id: 'update_1',
            date: DateTime.now().subtract(const Duration(days: 5)),
            title: 'Cease and Desist Notice Sent',
            description:
                'Official notice sent to competitor demanding immediate cessation.',
            type: 'action',
          ),
          CaseUpdate(
            id: 'update_2',
            date: DateTime.now().subtract(const Duration(days: 15)),
            title: 'Case Investigation Completed',
            description: 'Evidence of infringement confirmed and documented.',
            type: 'process',
          ),
        ],
        notes: 'Strong case with clear evidence. Expecting positive outcome.',
      ),
    ];
  }
}
