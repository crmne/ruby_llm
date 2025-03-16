# RubyLLM Development Rules and Guidelines

* prefer a TDD/BDD approach
* avoid mocks, use real objects instead, consider VCR
* Follow the design patterns of this existing repo
* Maintain consistent code organization and structure
* Follow Ruby best practices and conventions

## Core Architecture

1. **Provider Implementation**
   - Inherit from base Provider class
   - Implement required interface methods
   - Handle errors consistently
   - Follow established retry patterns

2. **Testing**
   - Write comprehensive RSpec tests
   - Use VCR for HTTP interactions
   - Maintain high test coverage
   - Test error scenarios

3. **Code Style**
   - Use Standard Ruby
   - Write clear documentation
   - Keep methods focused
   - Follow Ruby naming conventions

4. **Error Handling**
   - Use custom error classes
   - Implement proper retries
   - Provide meaningful messages
   - Log appropriately

5. **Security**
   - Never commit API keys
   - Use environment variables
   - Follow least privilege
   - Handle sensitive data properly

6. **Performance**
   - Implement caching where needed
   - Monitor resource usage
   - Handle timeouts properly
   - Clean up resources

7. **Documentation**
   - Document public interfaces
   - Provide usage examples
   - Keep docs up to date
   - Include type information