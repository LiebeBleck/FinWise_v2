"""Initial database schema

Revision ID: 001
Revises:
Create Date: 2026-02-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create users table
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('username', sa.String(length=100), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('hashed_password', sa.String(length=255), nullable=True),
        sa.Column('currency', sa.String(length=3), nullable=False),
        sa.Column('timezone', sa.String(length=50), nullable=False),
        sa.Column('theme', sa.String(length=10), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('last_sync_at', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # Create categories table
    op.create_table(
        'categories',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('color', sa.String(length=7), nullable=False),
        sa.Column('icon', sa.String(length=50), nullable=True),
        sa.Column('is_default', sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # Create transactions table
    op.create_table(
        'transactions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('category_id', sa.Integer(), nullable=True),
        sa.Column('amount', sa.Float(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('date', sa.DateTime(), nullable=False),
        sa.Column('receipt_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('ml_category', sa.String(length=100), nullable=True),
        sa.Column('ml_confidence', sa.Float(), nullable=True),
        sa.Column('is_anomaly', sa.Boolean(), nullable=False),
        sa.Column('device_id', sa.String(length=100), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['category_id'], ['categories.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_transactions_user_id'), 'transactions', ['user_id'], unique=False)
    op.create_index(op.f('ix_transactions_category_id'), 'transactions', ['category_id'], unique=False)
    op.create_index(op.f('ix_transactions_date'), 'transactions', ['date'], unique=False)

    # Create budgets table
    op.create_table(
        'budgets',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('monthly_amount', sa.Float(), nullable=False),
        sa.Column('period_start', sa.DateTime(), nullable=False),
        sa.Column('period_end', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_budgets_user_id'), 'budgets', ['user_id'], unique=False)
    op.create_index(op.f('ix_budgets_period_start'), 'budgets', ['period_start'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_budgets_period_start'), table_name='budgets')
    op.drop_index(op.f('ix_budgets_user_id'), table_name='budgets')
    op.drop_table('budgets')

    op.drop_index(op.f('ix_transactions_date'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_category_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_user_id'), table_name='transactions')
    op.drop_table('transactions')

    op.drop_table('categories')

    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
