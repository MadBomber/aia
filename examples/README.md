# Executable Prompts

Executable prompts are a powerful feature of the AI Assistant (`aia`) that enable users to create and run command-line utilities tailored to interact with AI models. These prompts can automate tasks, generate content, and incorporate custom configurations, making them highly versatile for various applications. In this section, we will delve deeper into the nature of executable prompts, how to configure them with directives, and provide an overview of practical examples.

## What is an Executable Prompt?

An executable prompt is a special type of prompt file that is structured to allow execution through the `aia` command-line interface. By including specific command-line behavior in the form of a shebang line, the prompt can be invoked directly from the terminal like any other executable script.

### Structure of an Executable Prompt

1. **Shebang Line**: The first line of the prompt indicates how the file should be executed. For instance:
   ```bash
   #!/usr/bin/env aia run --no-out_file
   ```

   This line tells the system to use the `aia` CLI with the `run` prompt ID for execution, while `--no-out_file` indicates that output should be sent to STDOUT instead of being written to a file.

2. **Content**: Below the shebang line, users can add the prompt content that will be sent to the AI model for processing. This content can use flexible directives and dynamic parameters.

### Example of an Executable Prompt

```bash
#!/usr/bin/env aia run --no-out_file
# File: top10
# Desc: The top 10 cities by population

What are the top 10 cities by population in the USA? Summarize what people like about living in each city. Include an average cost of living and links to the respective Wikipedia pages. Format your response as a markdown document.
```

After making this script executable with `chmod +x top10`, it can be run directly in the terminal:

```bash
./top10
```

## Using Directives to Configure Execution

Directives embedded within executable prompts allow users to configure various execution parameters dynamically. These directives are special commands within the prompt text that guide the prompt's behavior when processed by the AI model.

### Available Directives

#### 1. **//config**

The `//config` directive is used to modify configuration settings specifically for a particular execution of the prompt. You can set various parameters such as model selection, output handling, or chat mode:

```bash
//config model = gpt-4
//config out_file = results.md
```

**Example**: You can control the model and output settings dynamically without changing global or default settings.

#### 2. **//include**

This directive allows the inclusion of external files or content right into the prompt. This can be useful for injecting multiple lines of data or complex configurations:

```bash
//include path/to/config.txt
```

This will read the content of `config.txt` and prepend it to the prompt context.

#### 3. **//shell**

Execute shell commands dynamically and include their results in the prompt. This integration can enhance your prompts by feeding them real-time data:

```bash
//shell echo $(pwd)
```

This would prepend the current working directory to the prompt's input.

### Parameterization

Executable prompts can also accept parameters or keywords that users define themselves. For instance:

```bash
[MY_TOPIC]
```

When the prompt runs, users will be prompted to provide a value for `MY_TOPIC`, allowing for flexible and dynamic conversations with the AI model.

## Benefits of Executable Prompts

1. **Automation**: Automate complex tasks by wrapping them in a reusable script.
2. **Dynamic Content**: Use directives to dynamically adjust settings, include external data, and run system commands.
3. **Ease of Use**: Users can execute prompts directly from the terminal without entering the `aia` command each time.
4. **Configuration Flexibility**: Tailor specific prompt executions without altering global settings, giving you full control over the runtime environment.

## Practical Examples of Executable Prompts

### Example 1: Top 10 Cities Script

Create a script that gives information on the top cities in the USA:

```bash
#!/usr/bin/env aia run --no-out_file
# File: top10
# Desc: Retrieves top 10 cities by population

//config out_file=top10_cities.md

What are the top 10 cities by population in the USA? Summarize what people like about living in each city and include links to their respective Wikipedia pages.
```

### Example 2: Weather Report

```bash
#!/usr/bin/env aia run
# File: weather_report
# Desc: Gets today's weather

//shell curl -s 'wttr.in/Toronto?format=3'

Today's weather in Toronto is: $(cat weather_output.txt).
```

### Example 3: Dynamic Task Execution

A user can create a prompt for performing mathematical calculations:

```bash
#!/usr/bin/env aia run
# File: calculate
# Desc: Simple calculator

//config model=gpt-3

Please calculate [MATH_EXPRESSION].
```

When executed, the user is prompted to input the mathematical expression they want to calculate.

### Example of Using STDOUT and Piping

You can combine executable prompts with other shell commands to further manipulate the output:

```bash
./top10 | glow  # Pipe output to glow for rendering markdown in the terminal
```
