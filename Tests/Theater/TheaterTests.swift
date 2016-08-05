import XCTest
import Glibc
@testable import Theater

class TheaterTests: XCTestCase {
	func testPingPong() {
		let pp = PingPong()
		sleep(3)
		pp.stop()
	}

	func testGreetings() {
		let sys = GreetingActorController()
		sys.kickoff()
	}

	func testCloudEdge() {
		let count = 1000
		let system = ActorSystem(name: systemName)
		let _ = system.actorOf(Server.self, name: serverName)
		let monitor = system.actorOf(Monitor.self, name: monitorName)
		for i in 0..<count {
			let client = system.actorOf(Client.self, name: "Client\(i)")
			let timestamp = timeval(tv_sec: 0, tv_usec:0)
			client ! Request(client: i, server: 0, timestamp: timestamp)
			usleep(1000)
		}
		sleep(10)
		monitor ! ShowResult(sender: nil)
		system.stop()
		exit(0)
	}

	static var allTests: [(String, (TheaterTests) -> () throws -> Void)] {
		return [
			("testPingPong", testPingPong),
			("testGreetings", testGreetings),
			("testCloudEdge", testCloudEdge)
		]
	}
}