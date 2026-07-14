import { NextRequest, NextResponse } from 'next/server.js';
import { StoreAuthorizationError, verifyStoreAuthorization } from '../../lib/apple.js';
import { deleteUserQuota } from '../../lib/quota.js';

export async function POST(request: NextRequest) {
  try {
    const authorization = await verifyStoreAuthorization(request.headers);
    await deleteUserQuota(authorization.userId);
    return NextResponse.json({ success: true });
  } catch (error) {
    if (error instanceof StoreAuthorizationError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof Error && error.message === 'QUOTA_STORE_NOT_CONFIGURED') {
      return NextResponse.json({ error: 'Usage service unavailable' }, { status: 503 });
    }
    console.error('Delete-user error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
