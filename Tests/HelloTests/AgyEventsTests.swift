import XCTest
@testable import Hello

/// Flux `agy -p … --output-format stream-json`, d'après une vraie sortie d'Antigravity 1.5.17.
final class AgyEventsTests: XCTestCase {
    private let lines = [
        #"{"event":"init","conversation_id":"7745ba48","init":{"model":"gemini-3.8-flash-low","cwd":"/tmp","tools":[]}}"#,
        #"{"event":"step_update","step_update":{"conversation_id":"7745ba48","step_index":0,"state":"DONE","step_type":"user_input"}}"#,
        #"{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"run_command","tool_info":{"name":"run_command","parameters":{"CommandLine":"wc -l < /etc/shells"}}}}"#,
        #"{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"tool","tool_name":"run_command","tool_info":{"name":"run_command","parameters":{"CommandLine":"wc -l < /etc/shells"},"output":"11"}}}"#,
        #"{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"agent_response","text_delta":"DONE"}}"#,
        #"{"event":"step_update","step_update":{"step_index":3,"state":"DONE","step_type":"agent_response","text_delta":": 11\n"}}"#,
        #"{"event":"result","result":{"conversation_id":"7745ba48","status":"SUCCESS","response":"DONE: 11\n"}}"#,
    ]

    func testStreamBecomesSessionStepTextAndFinal() {
        let parser = EventParser(.agy)
        var session: String?, steps: [String] = [], text = "", final: String?
        for line in lines {
            for event in parser.feed(line) {
                switch event {
                case .session(let id): session = id
                case .step(let step): steps.append(step)
                case .text(let chunk): text += chunk
                case .final(let answer): final = answer
                case .failure(let message): XCTFail(message)
                }
            }
        }
        XCTAssertEqual(session, "7745ba48")
        XCTAssertEqual(steps, ["$ wc -l < /etc/shells"])
        XCTAssertEqual(text, "DONE: 11\n")
        XCTAssertEqual(final, "DONE: 11")
    }

    func testFailedResultIsAFailure() {
        let events = EventParser(.agy).feed(#"{"event":"result","result":{"status":"ERROR","response":"","error":"quota"}}"#)
        guard case .failure(let message)? = events.first else { return XCTFail("\(events)") }
        XCTAssertEqual(message, "quota")
    }
}
