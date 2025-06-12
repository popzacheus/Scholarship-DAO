# Scholarship DAO
A decentralized autonomous organization (DAO) for managing and distributing scholarship funds transparently on the Stacks blockchain.

## 🌟 Features

- 📝 Submit scholarship applications
- 🗳️ DAO member voting system
- 💰 Treasury management
- 🤝 Member management
- 📊 Application status tracking

## 🚀 Usage

### For DAO Administrators

1. Initialize DAO with owner:
```clarity
(contract-call? .scholarship-dao initialize-dao tx-sender)
```

2. Add DAO members:
```clarity
(contract-call? .scholarship-dao add-member 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

3. Fund treasury:
```clarity
(contract-call? .scholarship-dao fund-treasury u1000)
```

### For Applicants

1. Submit scholarship application:
```clarity
(contract-call? .scholarship-dao submit-application u500)
```

### For DAO Members

1. Vote on applications:
```clarity
(contract-call? .scholarship-dao vote-on-application u1)
```

## 📊 Query Functions

- Check application status: `get-application`
- View treasury balance: `get-treasury-balance`
- Verify DAO membership: `is-dao-member`

## 🔒 Security

- Only DAO owner can add/remove members
- Members can only vote once per application
- Automatic approval when vote threshold is met
- Built-in treasury management
```
