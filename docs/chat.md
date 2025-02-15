The ChatManager and ChatService classes serve different roles within the AIA system:

 1 ChatManager:
    • Purpose: Manages the chat session lifecycle, including setting up the session, handling user input, and
      processing chat interactions.
    • Responsibilities:
       • Initializes and manages the chat session.
       • Handles the chat loop, which involves getting user input and processing it.
       • Preprocesses prompts and handles directives.
       • Manages the display and logging of chat results.
    • Key Methods:
       • start_session: Begins the chat session and manages the loop for continuous interaction.
       • handle_chat_loop: Continuously processes user input until a termination condition is met.
       • process_chat_interaction: Processes each user input, handling directives or regular prompts.
 2 ChatService:
    • Purpose: Provides services related to chat processing, focusing on the interaction with the AI client and
      processing of prompts.
    • Responsibilities:
       • Processes chat prompts by interacting with the AI client.
       • Handles directives and regular prompts, logging and speaking results as needed.
       • Manages the preprocessing of prompts, including ERB and shell processing.
    • Key Methods:
       • process_chat: Main method to process a chat prompt, handling directives and regular prompts.
       • preprocess_prompt: Prepares the prompt by processing ERB and shell variables.
       • get_and_display_result: Interacts with the AI client to get and display the result.

In summary, ChatManager is more about managing the overall chat session and user interaction, while ChatService focuses
on the processing of individual chat prompts and interactions with the AI client.
