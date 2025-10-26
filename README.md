# MentorMatch AI

A decentralized mentorship platform built on Stacks blockchain that connects AI mentors and mentees through smart contracts.

## Features

- Mentor registration system
- Session booking with STX escrow
- Automated payment release upon session completion
- Feedback collection and rating system

## Smart Contract Functions

### Public Functions

- `register-mentor` - Register as a mentor on the platform
- `create-session` - Book a mentorship session with STX payment
- `complete-session` - Complete session and release payment with feedback

### Read-Only Functions

- `get-session` - Retrieve session details by ID
- `get-mentor` - Get mentor information
- `get-session-nonce` - Get current session counter

## Usage

Deploy the contract using Clarinet and interact through the Stacks blockchain.