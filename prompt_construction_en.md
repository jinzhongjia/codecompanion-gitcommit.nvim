# Universal Tool Description Pattern Specification

## Core Three-Part Structure

Each tool description must include the following three parts:

```
[Function Description]

When to use:
• [Use case 1]
• [Use case 2]
• [Use case 3]

Best practices:
• [Guideline 1]
• [Guideline 2]
• [Guideline 3]
```

---

## Detailed Specifications

### 1. Function Description Section
**Requirements**:
- **Length**: 20-50 characters
- **Format**: Start with verb, one sentence explaining core functionality
- **Tone**: Concise and clear, no modifiers

**Correct Examples**:
- ✅ "Execute system shell commands"
- ✅ "Read text file contents"
- ✅ "Send notification messages to user"
- ✅ "Navigate to specified URL in browser"

**Incorrect Examples**:
- ❌ "This powerful tool can help you execute various complex system command operations"
- ❌ "Utility tool for file reading"

### 2. When to Use Section
**Requirements**:
- **Quantity**: 2-4 scenarios
- **Beginning**: Consistently start with "When"
- **Specificity**: Clear trigger conditions, avoid vague expressions

**Correct Examples**:
- ✅ "When installing software packages"
- ✅ "When running automation scripts"
- ✅ "When checking system status"
- ✅ "When batch processing file operations"

**Incorrect Examples**:
- ❌ "When system-related operations are needed"
- ❌ "May be used in certain situations"
- ❌ "Depends on user requirements"

### 3. Best Practices Section
**Requirements**:
- **Quantity**: 2-6 guidelines
- **Beginning**: Use verbs like "Must", "Avoid", "Use", "Ensure"
- **Actionability**: Specific executable guidance principles

**Correct Examples**:
- ✅ "Must avoid commands requiring interactive confirmation"
- ✅ "Use -y parameter for automatic confirmation"
- ✅ "Avoid operations that take too long to execute"
- ✅ "Ensure command syntax is correct before execution"

**Incorrect Examples**:
- ❌ "Use with caution"
- ❌ "Pay attention to security issues"
- ❌ "Recommend careful operation"

---

## Application Examples

### Example 1: Shell Execution Tool
```
Execute commands in shell session

When to use:
• When running system commands
• When installing software packages
• When executing script files
• When performing file operations

Best practices:
• Must use -y parameter to avoid interactive confirmation
• Avoid commands with excessive output
• Use && to connect multiple related commands
• Ensure command safety before execution
```

### Example 2: File Reading Tool
```
Read text content of specified files

When to use:
• When viewing configuration files
• When analyzing log content
• When reading code files

Best practices:
• Ensure file path is correct
• Use line limits for large files
• Avoid reading binary files
```

### Example 3: Message Notification Tool
```
Send information notifications to user

When to use:
• When task completion needs reporting
• When progress updates need to be shown
• When important status changes occur

Best practices:
• Ensure message content is concise and clear
• Avoid sending notifications too frequently
• Must include relevant file attachments
```

---

## Quality Check Standards

### ✅ Qualification Standards
- [ ] Function description within 50 characters
- [ ] "When to use" includes 2-4 clear scenarios
- [ ] "Best practices" provides specific operational advice
- [ ] Language expression is concise and accurate
- [ ] Structure is complete with no missing parts

### ❌ Common Issues
- Function description too long or vague
- Use case descriptions too broad
- Best practices lack actionability
- Language too colloquial or insufficiently formal
- Incomplete structure

---

## Applicable Formats

This specification applies to any document format:

**Markdown Format**:
```markdown
## Tool Name
Function description text

### When to use
- Scenario 1
- Scenario 2

### Best practices
- Guideline 1
- Guideline 2
```

**Plain Text Format**:
```
Tool Name: Function description

When to use:
1. Scenario 1
2. Scenario 2

Best practices:
1. Guideline 1
2. Guideline 2
```

**JSON Format**:
```json
{
  "description": "Function description",
  "whenToUse": ["Scenario 1", "Scenario 2"],
  "bestPractices": ["Guideline 1", "Guideline 2"]
}
```

---

**Core Principle: Easy to understand, easy to learn, easy to use correctly**