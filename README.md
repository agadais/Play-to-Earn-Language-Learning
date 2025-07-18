# Play-to-Earn Language Learning Platform

A blockchain-based language learning game where players earn tokens for completing lessons and helping others learn.

## Features

- **Token Rewards**: Earn tokens for completing lessons based on difficulty and performance
- **Streak Bonuses**: Get multiplier rewards for maintaining daily learning streaks
- **Peer Help System**: Earn tokens by mentoring other learners
- **Lesson Rating**: Community-driven quality assurance through rating system
- **Multi-language Support**: Learn various languages with dedicated statistics
- **Level Progression**: Advance through levels based on completed lessons
- **Smart Contracts**: Fully decentralized on Stacks blockchain

## Getting Started

1. Clone this repository
2. Install Clarinet
3. Run `clarinet check` to validate contracts
4. Run `clarinet test` to execute tests
5. Deploy to testnet using `clarinet deploy`

## Contract Functions

### User Management
- `create-user-profile`: Initialize user profile with preferred language
- `get-user-profile`: Retrieve user statistics and progress

### Learning System
- `create-lesson`: Create new learning content (requires content hash)
- `complete-lesson`: Mark lesson as completed and claim rewards
- `rate-lesson`: Provide feedback and ratings for lessons

### Token System
- `transfer-tokens`: Send tokens between users
- `get-token-balance`: Check current token balance
- `help-user`: Earn tokens by helping others

## Smart Contract Architecture

The contract implements a comprehensive learning ecosystem with:
- User profiles with streak tracking
- Lesson management with difficulty scaling
- Token economics with multiple reward mechanisms
- Community features like rating and mentoring
- Administrative controls for content moderation

## Testing

Run the test suite with:
```bash
clarinet test
```

## Deployment

Deploy to testnet:
```bash
clarinet deploy --testnet
```

## Contributing

Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License.

