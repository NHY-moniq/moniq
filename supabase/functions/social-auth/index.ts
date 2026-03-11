import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface SocialAuthRequest {
  provider: 'kakao' | 'naver';
  access_token: string;
}

interface KakaoUser {
  id: number;
  kakao_account?: {
    email?: string;
    profile?: {
      nickname?: string;
      profile_image_url?: string;
    };
  };
}

interface NaverUser {
  response: {
    id: string;
    email?: string;
    name?: string;
    profile_image?: string;
  };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { provider, access_token }: SocialAuthRequest = await req.json();

    if (!provider || !access_token) {
      return new Response(
        JSON.stringify({ error: 'provider and access_token are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    let email: string | undefined;
    let displayName: string | undefined;
    let avatarUrl: string | undefined;
    let providerId: string;

    if (provider === 'kakao') {
      const res = await fetch('https://kapi.kakao.com/v2/user/me', {
        headers: { Authorization: `Bearer ${access_token}` },
      });

      if (!res.ok) {
        throw new Error('Failed to verify Kakao token');
      }

      const kakaoUser: KakaoUser = await res.json();
      providerId = `kakao_${kakaoUser.id}`;
      email = kakaoUser.kakao_account?.email;
      displayName = kakaoUser.kakao_account?.profile?.nickname;
      avatarUrl = kakaoUser.kakao_account?.profile?.profile_image_url;
    } else if (provider === 'naver') {
      const res = await fetch('https://openapi.naver.com/v1/nid/me', {
        headers: { Authorization: `Bearer ${access_token}` },
      });

      if (!res.ok) {
        throw new Error('Failed to verify Naver token');
      }

      const naverUser: NaverUser = await res.json();
      providerId = `naver_${naverUser.response.id}`;
      email = naverUser.response.email;
      displayName = naverUser.response.name;
      avatarUrl = naverUser.response.profile_image;
    } else {
      return new Response(
        JSON.stringify({ error: 'Unsupported provider' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!email) {
      return new Response(
        JSON.stringify({ error: '이메일 정보를 가져올 수 없습니다' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Check if user exists
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
    const existingUser = existingUsers?.users?.find(
      (u) => u.email === email,
    );

    let userId: string;

    if (existingUser) {
      userId = existingUser.id;
    } else {
      const { data: newUser, error: createError } =
        await supabaseAdmin.auth.admin.createUser({
          email,
          email_confirm: true,
          user_metadata: {
            display_name: displayName,
            avatar_url: avatarUrl,
            provider,
            provider_id: providerId,
          },
        });

      if (createError) {
        throw createError;
      }

      userId = newUser.user.id;
    }

    // Generate session token
    const { data: session, error: signInError } =
      await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: email,
      });

    if (signInError) {
      throw signInError;
    }

    return new Response(
      JSON.stringify({
        user_id: userId,
        email,
        display_name: displayName,
        token: session.properties?.hashed_token,
        verification_url: session.properties?.verification_url,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
