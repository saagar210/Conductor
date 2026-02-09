import Foundation
import SwiftData
import os

enum MockDataFactory {
    private static let logger = Logger(subsystem: "com.conductor.app", category: "models")

    @MainActor
    static func createMockSessions(in context: ModelContext) -> Session {
        let session1 = createAuthSession(in: context)
        let session2 = createDockerSession(in: context)

        logger.info("Created mock data: 2 sessions")
        return session1
    }

    @MainActor
    private static func createAuthSession(in context: ModelContext) -> Session {
        let now = Date()
        let session = Session(
            name: "Implement Authentication Module",
            slug: "implement-auth-module",
            sourceDir: "/Users/dev/projects/webapp",
            logPath: "~/.claude/projects/webapp/abc123.jsonl",
            rootPrompt: "Implement a complete authentication module with JWT tokens, password hashing, and role-based access control",
            status: .active,
            startedAt: now.addingTimeInterval(-1800), // 30 min ago
            totalTokens: 135_700,
            totalDuration: 1800,
            tagsRaw: "swift,auth,backend"
        )
        context.insert(session)

        // Root orchestrator
        let root = AgentNode(
            session: session,
            agentType: .orchestrator,
            agentName: "Orchestrator",
            task: "Implement a complete authentication module with JWT tokens, password hashing, and role-based access control. This involves exploring the existing codebase, planning the implementation, writing the code, and testing it.",
            result: "",
            status: .running,
            startedAt: now.addingTimeInterval(-1800),
            duration: 1800,
            tokenCount: 12_400,
            depth: 0
        )
        context.insert(root)

        // Explore subagent
        let explore = AgentNode(
            session: session,
            parent: root,
            agentType: .subagent,
            agentName: "Explore",
            task: "Explore the existing codebase to understand the project structure, existing auth patterns, database schema, and middleware setup.",
            result: "Found Express.js app with Prisma ORM. No existing auth. Has middleware pattern in /src/middleware/. Database has User model without password field. Using TypeScript with strict mode.",
            status: .completed,
            startedAt: now.addingTimeInterval(-1800),
            completedAt: now.addingTimeInterval(-1500),
            duration: 300,
            tokenCount: 34_200,
            depth: 1
        )
        context.insert(explore)
        addExploreToolCalls(to: explore, baseTime: now.addingTimeInterval(-1800), context: context)

        // Plan subagent
        let plan = AgentNode(
            session: session,
            parent: root,
            agentType: .subagent,
            agentName: "Plan",
            task: "Create a detailed implementation plan for the authentication module based on the codebase exploration results.",
            result: "Implementation plan:\n1. Add bcrypt + jsonwebtoken dependencies\n2. Update Prisma schema with password, role fields\n3. Create auth middleware for JWT verification\n4. Create /auth/register and /auth/login routes\n5. Add role-based guards\n6. Write integration tests",
            status: .completed,
            startedAt: now.addingTimeInterval(-1500),
            completedAt: now.addingTimeInterval(-1320),
            duration: 180,
            tokenCount: 18_500,
            depth: 1
        )
        context.insert(plan)
        addPlanToolCalls(to: plan, baseTime: now.addingTimeInterval(-1500), context: context)

        // Implement subagent
        let implement = AgentNode(
            session: session,
            parent: root,
            agentType: .subagent,
            agentName: "Implement",
            task: "Implement the authentication module following the approved plan. Create all necessary files, update the database schema, and wire up the routes.",
            result: "",
            status: .running,
            startedAt: now.addingTimeInterval(-1320),
            duration: 480,
            tokenCount: 52_300,
            depth: 1,
            filesModifiedRaw: "src/schema.prisma|||src/app.ts|||src/routes/index.ts|||package.json",
            filesCreatedRaw: "src/middleware/auth.ts|||src/routes/auth.ts|||src/utils/jwt.ts|||src/utils/password.ts"
        )
        context.insert(implement)
        addImplementToolCalls(to: implement, baseTime: now.addingTimeInterval(-1320), context: context)
        addImplementCommands(to: implement, baseTime: now.addingTimeInterval(-1100), context: context)

        // CodeReview sub-subagent (depth 2, child of Implement)
        let codeReview = AgentNode(
            session: session,
            parent: implement,
            agentType: .subagent,
            agentName: "CodeReview",
            task: "Review the implemented authentication code for security issues, best practices, and potential vulnerabilities.",
            result: "Code review passed. Found minor issue: JWT expiry should use environment variable instead of hardcoded value. Suggested fix applied. No SQL injection risks — Prisma handles parameterization. Password hashing uses bcrypt with cost factor 12 (good).",
            status: .completed,
            startedAt: now.addingTimeInterval(-900),
            completedAt: now.addingTimeInterval(-840),
            duration: 60,
            tokenCount: 8_100,
            depth: 2
        )
        context.insert(codeReview)
        addCodeReviewToolCalls(to: codeReview, baseTime: now.addingTimeInterval(-900), context: context)

        // TestRunner subagent (failed)
        let testRunner = AgentNode(
            session: session,
            parent: root,
            agentType: .subagent,
            agentName: "TestRunner",
            task: "Run the existing test suite to verify nothing is broken by the new authentication module.",
            result: "",
            status: .failed,
            startedAt: now.addingTimeInterval(-840),
            completedAt: now.addingTimeInterval(-790),
            duration: 50,
            tokenCount: 8_200,
            depth: 1,
            errorMessage: "Test suite failed: 3 tests failing. Database connection timeout in auth.test.ts — the test database container is not running. Error: connect ECONNREFUSED 127.0.0.1:5433"
        )
        context.insert(testRunner)
        addTestRunnerCommand(to: testRunner, baseTime: now.addingTimeInterval(-840), context: context)

        // WriteTests subagent (pending)
        let writeTests = AgentNode(
            session: session,
            parent: root,
            agentType: .subagent,
            agentName: "WriteTests",
            task: "Write comprehensive unit and integration tests for the new authentication module, covering registration, login, token refresh, and role-based access.",
            result: "",
            status: .pending,
            tokenCount: 0,
            depth: 1
        )
        context.insert(writeTests)

        return session
    }

    @MainActor
    private static func createDockerSession(in context: ModelContext) -> Session {
        let now = Date()
        let session = Session(
            name: "Fix Docker Build Pipeline",
            slug: "fix-docker-build",
            sourceDir: "/Users/dev/projects/webapp",
            logPath: "~/.claude/projects/webapp/def456.jsonl",
            rootPrompt: "Fix the Docker build pipeline — the multi-stage build is failing on the production stage",
            status: .completed,
            startedAt: now.addingTimeInterval(-7200), // 2 hours ago
            completedAt: now.addingTimeInterval(-6000),
            totalTokens: 23_100,
            totalDuration: 1200,
            isBookmarked: true,
            tagsRaw: "docker,devops,ci"
        )
        context.insert(session)

        let root = AgentNode(
            session: session,
            agentType: .orchestrator,
            agentName: "Orchestrator",
            task: "Fix the Docker build pipeline — the multi-stage build is failing on the production stage. Diagnose and resolve.",
            result: "Fixed Docker build. Root cause: Node.js 20 Alpine base image changed its default user. Updated Dockerfile to explicitly set user permissions in the production stage. Build now succeeds in 45s (down from timeout).",
            status: .completed,
            startedAt: now.addingTimeInterval(-7200),
            completedAt: now.addingTimeInterval(-6000),
            duration: 1200,
            tokenCount: 23_100,
            depth: 0,
            filesModifiedRaw: "Dockerfile|||.github/workflows/build.yml"
        )
        context.insert(root)

        return session
    }

    // MARK: - Tool Call Helpers

    @MainActor
    private static func addExploreToolCalls(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let tools: [(String, String, String, Double)] = [
            ("Glob", "**/*.ts", "Found 42 TypeScript files", 0),
            ("Read", "src/app.ts", "Express app setup with middleware chain...", 5),
            ("Read", "src/schema.prisma", "model User { id Int @id @default(autoincrement()) ... }", 10),
            ("Read", "src/middleware/cors.ts", "CORS middleware configuration", 15),
            ("Read", "src/routes/index.ts", "Route definitions for /api/users, /api/posts", 20),
            ("Grep", "password|auth|jwt|token", "No matches found in source files", 30),
            ("Read", "package.json", "Dependencies: express, prisma, typescript...", 40),
            ("Grep", "middleware", "src/app.ts:12: app.use(corsMiddleware)...", 50),
            ("Bash", "npx prisma db pull", "Pulled schema from database", 60),
            ("Glob", "src/middleware/**/*", "Found: cors.ts, logger.ts, errorHandler.ts", 80),
            ("Read", "src/middleware/errorHandler.ts", "Error handling middleware with custom AppError class", 90),
            ("Grep", "process.env", "Found 8 env variable references", 100),
            ("Read", ".env.example", "DATABASE_URL=postgresql://...", 110),
            ("Bash", "npm ls --depth=0", "Listed 15 direct dependencies", 120),
            ("Glob", "tests/**/*.test.ts", "Found 12 test files", 140),
        ]

        for (i, (name, input, output, offset)) in tools.enumerated() {
            let record = ToolCallRecord(
                node: node,
                toolName: name,
                input: input,
                output: output,
                status: .succeeded,
                executedAt: baseTime.addingTimeInterval(offset)
            )
            context.insert(record)
        }
    }

    @MainActor
    private static func addPlanToolCalls(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let tools: [(String, String, String, Double)] = [
            ("Read", "src/schema.prisma", "Current schema review for planning", 0),
            ("Grep", "bcrypt|argon2|scrypt", "No password hashing library found", 10),
            ("Read", "tsconfig.json", "TypeScript config with strict mode enabled", 20),
            ("Bash", "npm search jsonwebtoken --json | head -5", "jsonwebtoken@9.0.0 available", 30),
            ("Write", "docs/auth-plan.md", "Wrote implementation plan document", 60),
        ]

        for (name, input, output, offset) in tools {
            let record = ToolCallRecord(
                node: node,
                toolName: name,
                input: input,
                output: output,
                status: .succeeded,
                executedAt: baseTime.addingTimeInterval(offset)
            )
            context.insert(record)
        }
    }

    @MainActor
    private static func addImplementToolCalls(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let tools: [(String, String, String, Double)] = [
            ("Write", "src/utils/password.ts", "Created password hashing utility with bcrypt", 0),
            ("Write", "src/utils/jwt.ts", "Created JWT token generation and verification", 20),
            ("Write", "src/middleware/auth.ts", "Created auth middleware for route protection", 40),
            ("Write", "src/routes/auth.ts", "Created /register and /login endpoints", 60),
            ("Edit", "src/schema.prisma", "Added password, role, refreshToken fields to User model", 80),
            ("Edit", "src/app.ts", "Wired auth routes and middleware", 100),
            ("Edit", "src/routes/index.ts", "Added auth route imports", 120),
            ("Edit", "package.json", "Added bcrypt, jsonwebtoken dependencies", 140),
            ("Read", "src/middleware/auth.ts", "Verified auth middleware implementation", 160),
        ]

        for (name, input, output, offset) in tools {
            let record = ToolCallRecord(
                node: node,
                toolName: name,
                input: input,
                output: output,
                status: .succeeded,
                executedAt: baseTime.addingTimeInterval(offset)
            )
            context.insert(record)
        }
    }

    @MainActor
    private static func addImplementCommands(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let cmd1 = CommandRecord(
            node: node,
            command: "npm install bcrypt jsonwebtoken @types/bcrypt @types/jsonwebtoken",
            exitCode: 0,
            stdout: "added 4 packages in 3.2s",
            stderr: "",
            duration: 3.2,
            executedAt: baseTime
        )
        context.insert(cmd1)

        let cmd2 = CommandRecord(
            node: node,
            command: "npx prisma migrate dev --name add-auth-fields",
            exitCode: 0,
            stdout: "Applying migration `20240115_add_auth_fields`\nMigration applied successfully.",
            stderr: "",
            duration: 4.8,
            executedAt: baseTime.addingTimeInterval(10)
        )
        context.insert(cmd2)

        let cmd3 = CommandRecord(
            node: node,
            command: "npx tsc --noEmit",
            exitCode: 1,
            stdout: "",
            stderr: "src/routes/auth.ts(42,5): error TS2345: Argument of type 'string | undefined' is not assignable to parameter of type 'string'.",
            duration: 2.1,
            executedAt: baseTime.addingTimeInterval(20)
        )
        context.insert(cmd3)
    }

    @MainActor
    private static func addCodeReviewToolCalls(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let tools: [(String, String, String, Double)] = [
            ("Read", "src/utils/jwt.ts", "Reviewed JWT implementation — found hardcoded expiry", 0),
            ("Read", "src/middleware/auth.ts", "Reviewed auth middleware — looks good", 10),
            ("Read", "src/routes/auth.ts", "Reviewed auth routes — input validation present", 20),
        ]

        for (name, input, output, offset) in tools {
            let record = ToolCallRecord(
                node: node,
                toolName: name,
                input: input,
                output: output,
                status: .succeeded,
                executedAt: baseTime.addingTimeInterval(offset)
            )
            context.insert(record)
        }
    }

    @MainActor
    private static func addTestRunnerCommand(to node: AgentNode, baseTime: Date, context: ModelContext) {
        let cmd = CommandRecord(
            node: node,
            command: "npx vitest run",
            exitCode: 1,
            stdout: "Running 12 tests...\n PASS  tests/users.test.ts (5 tests)\n PASS  tests/posts.test.ts (4 tests)\n FAIL  tests/auth.test.ts (3 tests)",
            stderr: "Error: connect ECONNREFUSED 127.0.0.1:5433\n    at TCPConnectWrap.afterConnect [as oncomplete] (net.js:1141:16)",
            duration: 12.5,
            executedAt: baseTime
        )
        context.insert(cmd)
    }
}
