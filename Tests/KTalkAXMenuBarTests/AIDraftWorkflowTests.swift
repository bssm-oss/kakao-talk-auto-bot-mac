import Testing
@testable import KTalkAXMenuBarApp

struct AIDraftWorkflowTests {
    @Test func draftRequestIncludesInstructionsAndExistingNotes() {
        let request = AIDraftRequestFactory.makeRequest(
            action: .draft,
            chatTitle: "Project Room",
            instructions: "Polite reminder about the 3pm review.",
            currentMessage: "Mention the updated deck link."
        )

        #expect(request.systemPrompt?.contains("Return only the final message text") == true)
        #expect(request.userPrompt.contains("Project Room"))
        #expect(request.userPrompt.contains("Polite reminder about the 3pm review."))
        #expect(request.userPrompt.contains("Mention the updated deck link."))
    }

    @Test func rewriteRequestFallsBackToDefaultRewriteGoal() {
        let request = AIDraftRequestFactory.makeRequest(
            action: .rewrite,
            chatTitle: "Ops",
            instructions: "   ",
            currentMessage: "Can you please check this today"
        )

        #expect(request.userPrompt.contains("Improve clarity, flow, and tone while keeping the same intent."))
        #expect(request.userPrompt.contains("Can you please check this today"))
    }
}
