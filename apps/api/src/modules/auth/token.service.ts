import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export type PrincipalRole = 'child' | 'parent' | 'teacher' | 'admin' | 'super_admin';

export interface WatotoClaims {
  sub: string;
  role: PrincipalRole;
  familyId?: string;
  childId?: string;
  ent?: string;
}

@Injectable()
export class TokenService {
  constructor(private readonly jwt: JwtService) {}

  async issueAccessToken(claims: WatotoClaims): Promise<string> {
    return this.jwt.signAsync(claims);
  }

  async verify(token: string): Promise<WatotoClaims> {
    return this.jwt.verifyAsync<WatotoClaims>(token);
  }
}
