# Image Generation

AIA supports AI-powered image generation through various models, enabling you to create images from text descriptions, modify existing images, and integrate visual content generation into your workflows.

## Supported Models

### DALL-E Models (OpenAI)
- **DALL-E 3**: Latest and most capable image generation model
- **DALL-E 2**: Previous generation, still available and capable

### Image Model Capabilities
```bash
# Check available image generation models
aia --available_models text_to_image

# Example output:
# - dall-e-3 (openai) text to image
# - dall-e-2 (openai) text to image
```

## Basic Image Generation

### Simple Image Generation
```bash
# Generate an image with default settings
aia --model dall-e-3 "A serene mountain lake at sunset"

# Generate with specific size
aia --model dall-e-3 --image_size 1024x1024 "Modern office workspace"

# Generate with quality settings
aia --model dall-e-3 --image_quality hd "Professional headshot"
```

### Image Configuration Options

#### Image Size (`--image_size`, `--is`)
```bash
# Square formats
aia --image_size 1024x1024 "Square image prompt"
aia --is 512x512 "Smaller square image"

# Landscape formats  
aia --image_size 1792x1024 "Wide landscape image"
aia --is 1344x768 "Medium landscape"

# Portrait formats
aia --image_size 1024x1792 "Tall portrait image"
aia --is 768x1344 "Medium portrait"
```

**Available sizes**:
- Square: `256x256`, `512x512`, `1024x1024`
- Landscape: `1792x1024`, `1344x768`
- Portrait: `1024x1792`, `768x1344`

#### Image Quality (`--image_quality`, `--iq`)
```bash
# Standard quality (faster, less expensive)
aia --image_quality standard "Quick concept image"

# HD quality (better detail, more expensive)  
aia --image_quality hd "High-quality marketing image"
aia --iq hd "Detailed technical diagram"
```

**Quality options**:
- `standard`: Good quality, faster generation, lower cost
- `hd`: Enhanced detail and resolution, slower, higher cost

#### Image Style (`--style`, `--image_style`)
```bash
# Vivid style (hyper-real, dramatic colors)
aia --image_style vivid "Dramatic sunset over city skyline"

# Natural style (more natural, less stylized)
aia --image_style natural "Realistic portrait of a person reading"
aia --style natural "Documentary-style photograph"
```

**Style options**:
- `vivid`: Hyper-real and dramatic images
- `natural`: More natural, less stylized results

## Advanced Image Generation

### Using Prompts for Image Generation
Create reusable image generation prompts:

```markdown
# ~/.prompts/product_photography.txt
//config model dall-e-3
//config image_size 1024x1024
//config image_quality hd
//config image_style natural

# Product Photography Generator

Generate a professional product photograph of: <%= product %>

Style requirements:
- Clean, minimalist background
- Professional lighting
- Commercial photography style
- <%= lighting || "Soft, even lighting" %>
- <%= background || "White background" %>

Additional specifications:
- Angle: <%= angle || "45-degree angle" %>
- Context: <%= context || "Isolated product shot" %>
- Mood: <%= mood || "Clean and professional" %>
```

```bash
# Use the prompt
aia product_photography --product "wireless headphones" --lighting "dramatic side lighting"
```

### Complex Image Descriptions
```markdown
# ~/.prompts/detailed_scene.txt
//config model dall-e-3
//config image_size 1792x1024
//config image_quality hd
//config image_style vivid

# Detailed Scene Generator

Create a detailed image of: <%= scene_type %>

## Visual Elements:
- Setting: <%= setting %>
- Time of day: <%= time_of_day || "golden hour" %>
- Weather: <%= weather || "clear" %>
- Color palette: <%= colors || "warm and inviting" %>

## Composition:
- Perspective: <%= perspective || "eye level" %>
- Focal point: <%= focal_point %>
- Depth of field: <%= depth || "shallow depth of field" %>

## Style and Mood:
- Art style: <%= art_style || "photorealistic" %>
- Mood: <%= mood || "peaceful and serene" %>
- Technical quality: <%= quality || "professional photography" %>

Generate a <%= scene_type %> scene with <%= focal_point %> as the main subject, 
set in <%= setting %> during <%= time_of_day %>.
```

### Image Series Generation
```ruby
# ~/.prompts/image_series.txt
//config model dall-e-3
//config image_size 1024x1024

# Image Series Generator

//ruby
series_theme = '<%= theme %>'
variations = ['<%= var1 %>', '<%= var2 %>', '<%= var3 %>']
base_prompt = '<%= base_description %>'

puts "Generating #{variations.length} variations of #{series_theme}:"
puts

variations.each_with_index do |variation, index|
  puts "## Image #{index + 1}: #{variation.capitalize}"
  puts "#{base_prompt} featuring #{variation}."
  puts "Style: Consistent with series theme of #{series_theme}"
  puts
end
```

```bash
# Generate a series
aia image_series \
  --theme "modern architecture" \
  --base_description "Professional architectural photograph" \
  --var1 "glass and steel skyscraper" \
  --var2 "minimalist residential house" \
  --var3 "contemporary office building"
```

## Image Generation Workflows

### Marketing Asset Pipeline
```markdown
# ~/.prompts/marketing_pipeline.txt
//pipeline concept_image,hero_image,detail_shots,social_media_variants

# Marketing Asset Generation Pipeline

Product: <%= product_name %>
Brand style: <%= brand_style || "modern and clean" %>
Target audience: <%= audience || "professionals" %>

## Stage 1: Concept Image
//config model dall-e-3
//config image_size 1024x1024
//config image_style natural

Generate initial concept image for <%= product_name %>:
- Style: <%= brand_style %>
- Context: Product introduction
- Purpose: Initial concept validation

//next hero_image
```

### Creative Workflow
```markdown
# ~/.prompts/creative_workflow.txt
//config model dall-e-3
//config image_quality hd
//config image_style vivid

# Creative Image Workflow

Theme: <%= creative_theme %>
Artistic direction: <%= art_direction %>

## Brainstorming Phase
Generate 3 conceptual variations of <%= creative_theme %>:

1. **Abstract interpretation**: Focus on mood and emotion
2. **Realistic approach**: Photographic, detailed representation  
3. **Stylized version**: Artistic, illustrative style

Each image should embody <%= art_direction %> while exploring different artistic approaches.
```

## Integration with Other AIA Features

### Image Generation in Chat Mode
```bash
# Start chat with image generation capability
aia --chat --model dall-e-3

You: Generate an image of a cozy coffee shop interior
AI: I'll create that image for you...

You: Now make it more modern and minimalist
AI: Here's a more modern version...

You: Can you create a series showing different times of day?
AI: I'll generate morning, afternoon, and evening versions...
```

### Combining Text and Image Generation
```markdown
# ~/.prompts/content_with_visuals.txt
//config model gpt-4

# Content + Visuals Generator

Topic: <%= topic %>

## Step 1: Generate Written Content
Create comprehensive content about <%= topic %>:
- Introduction and overview
- Key concepts and explanations
- Practical applications
- Conclusion and takeaways

## Step 2: Identify Visual Opportunities  
Based on the content, suggest 3-5 images that would enhance understanding:
- Conceptual illustrations
- Diagrams or infographics
- Real-world examples
- Supporting visuals

## Step 3: Generate Image Prompts
For each suggested visual, provide detailed DALL-E prompts that would create appropriate images.

//next generate_supporting_images
```

### Technical Documentation with Visuals
```markdown
# ~/.prompts/technical_docs_with_images.txt
//config model gpt-4

# Technical Documentation with Visual Aids

System/Process: <%= system_name %>

## Documentation Phase
Create technical documentation for <%= system_name %> including:
- Architecture overview
- Process flows  
- Component relationships
- User interfaces

## Visual Requirements Analysis
Identify diagrams and illustrations needed:
- System architecture diagrams
- Process flow charts
- UI mockups
- Component diagrams

## Image Generation Specifications
For each identified visual need, create detailed prompts for:
- Technical diagram style
- Professional color schemes
- Appropriate level of detail
- Consistent visual language

//next technical_image_generation
```

## Best Practices for Image Generation

### Effective Prompt Writing

#### Be Specific and Detailed
```bash
# Vague prompt (poor results)
aia --model dall-e-3 "office space"

# Detailed prompt (better results)
aia --model dall-e-3 "Modern open-plan office with floor-to-ceiling windows, ergonomic furniture, plants, natural lighting, clean minimal aesthetic, professional photography style"
```

#### Use Style and Technical Terms
```bash
# Include photography terms
aia --model dall-e-3 "Portrait with shallow depth of field, golden hour lighting, 85mm lens perspective"

# Include art style references
aia --model dall-e-3 "Landscape in the style of landscape photography, dramatic sky, wide angle lens, HDR processing"
```

#### Specify Composition Elements
```bash
# Composition guidance
aia --model dall-e-3 "Centered composition, symmetrical balance, rule of thirds, leading lines toward focal point"
```

### Quality Optimization

#### Resolution and Size Selection
```bash
# Choose size based on use case
aia --image_size 1792x1024 "Website hero image"      # Landscape
aia --image_size 1024x1792 "Mobile app screenshot"   # Portrait
aia --image_size 1024x1024 "Social media post"       # Square
```

#### Quality vs. Cost Balance
```bash
# Standard for concepts/drafts
aia --image_quality standard "Initial concept image"

# HD for final/published images
aia --image_quality hd "Final marketing image"
```

### Iterative Refinement
```bash
# Generate initial concept
aia --model dall-e-3 --output concept_v1.png "Modern kitchen design"

# Refine based on results
aia --model dall-e-3 --output concept_v2.png "Modern kitchen with marble countertops, pendant lighting, minimalist cabinets"

# Final version with specific details
aia --model dall-e-3 --image_quality hd --output final_kitchen.png "Ultra-modern kitchen with white marble waterfall countertops, brass pendant lights, handleless cabinets, large island, professional photography"
```

## Troubleshooting Image Generation

### Common Issues

#### Content Policy Violations
```
Error: Your request was rejected as a result of our safety system.
```
**Solution**: Revise prompt to avoid:
- Inappropriate content
- Copyrighted material references
- Specific person names (unless historical figures)

#### Unclear or Generic Results
**Problem**: Generated images are too generic or don't match expectations

**Solutions**:
```bash
# Add more specific details
aia --model dall-e-3 "Specific, detailed description with style, lighting, and composition details"

# Use technical photography terms
aia --model dall-e-3 "Subject photographed with 50mm lens, f/2.8, natural lighting, professional studio setup"
```

#### Size/Quality Issues
**Problem**: Images are not the right dimensions or quality

**Solutions**:
```bash
# Specify exact requirements
aia --model dall-e-3 --image_size 1792x1024 --image_quality hd "Detailed prompt"

# Match use case to settings
aia --is 1024x1024 --iq standard "Social media post"  # Standard for social media
aia --is 1792x1024 --iq hd "Website banner"           # HD for web headers
```

### Performance Optimization

#### Batch Generation
```ruby
# Generate multiple related images
//ruby
concepts = ['<%= concept1 %>', '<%= concept2 %>', '<%= concept3 %>']
base_style = '<%= base_style %>'

concepts.each_with_index do |concept, index|
  puts "\n## Image #{index + 1}: #{concept}"
  puts "#{base_style} featuring #{concept}"
end
```

#### Cost Management
```bash
# Use standard quality for iterations
aia --image_quality standard "Draft version for review"

# Use HD only for finals
aia --image_quality hd "Final approved concept"
```

## Integration Examples

### Blog Post with Custom Images
```markdown
# ~/.prompts/illustrated_blog.txt
//config model gpt-4

# Illustrated Blog Post Generator

Topic: <%= blog_topic %>
Target audience: <%= audience %>

## Content Creation
Write a comprehensive blog post about <%= blog_topic %> for <%= audience %>:
- Engaging introduction
- 3-4 main sections with subheadings
- Practical examples and tips
- Compelling conclusion

## Visual Content Planning
For each main section, identify opportunities for custom images:
- Hero image for the post
- Illustrative images for key concepts
- Supporting visuals for examples

## Image Generation Prompts
Create detailed DALL-E prompts for each identified visual:
- Consistent style across all images
- Professional quality specifications
- Appropriate for <%= audience %>
- Enhances the written content

//next generate_blog_images
```

### Product Documentation
```markdown
# ~/.prompts/product_docs_visual.txt
//pipeline analyze_product,create_documentation,identify_visuals,generate_images

# Product Documentation with Visuals

Product: <%= product_name %>
Documentation type: <%= doc_type %>

## Phase 1: Product Analysis
Analyze <%= product_name %> to understand:
- Key features and benefits
- User interface elements
- Use cases and workflows
- Target user needs

## Phase 2: Visual Requirements
Identify images needed for effective documentation:
- Product screenshots/mockups
- Feature highlight images
- User workflow diagrams
- Conceptual illustrations

//config model dall-e-3
//config image_quality hd
//config image_style natural
```

## Related Documentation

- [Working with Models](models.md) - Model selection and configuration
- [CLI Reference](../cli-reference.md) - Image generation command options
- [Advanced Prompting](../advanced-prompting.md) - Complex image generation techniques
- [Chat Mode](chat.md) - Interactive image generation
- [Workflows and Pipelines](../workflows-and-pipelines.md) - Image generation workflows

---

Image generation opens up new creative possibilities with AIA. Experiment with different prompts, styles, and configurations to create compelling visual content for your projects!