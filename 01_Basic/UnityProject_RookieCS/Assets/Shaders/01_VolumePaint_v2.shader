Shader "Cell/VolumePaint"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _ObjectColor ("Object Color", Color) = (1,1,1,1)
        _AmbientLight ("Ambient Light", Color) = (0.20,0.30,0.40,1)
        
        _Specular ("Specular", Range(1,200)) = 3
        _SpecularAlpha ("Specular Alpha", Range(0,1)) = 0
        _CellSpecular ("Cell Specular", Range(1,200)) = 20.0
        _CellSpecularAlpha ("Cell Specular Alpha", Range(0,1)) = 0.1
        
        _LightLimit ("Light Limit", Range(-1,1)) = 0
        _LightRange ("Light Range", Range(0,1)) = 0.2
        _PenumbraIntensity ("Penumbra Intensity", Range(0,1)) = 0.5
        _PenumbraRange ("Penumbra Range", Range(0,1)) = 0.2
        _ShadowLimit ("Shadow Limit", Range(-1,1)) = -0.5
        _ShadowIntensity ("Shadow Intensity", Range(0,1)) = 0.2
        _ShadowRange ("Shadow Range", Range(0,1)) = 0.2

        _DarkenViewTangent ("Darken View Tangent", Range(0,1)) = 0.1        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "AutoLight.cginc"

            // Comes from Mesh and into Vertex Shader
            struct VertexInput
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                float4 colors : COLOR;
                float4 tangent : TANGENT;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;                
            };
            
            fixed4 _ObjectColor;
            fixed4 _AmbientLight;
            
            float _Specular;
            float _SpecularAlpha;
            float _CellSpecular;
            float _CellSpecularAlpha;
            
            float _LightLimit;
            float _LightRange;            
            float _PenumbraIntensity;
            float _PenumbraRange;
            float _ShadowLimit;
            float _ShadowIntensity;
            float _ShadowRange;
            
            float _DarkenViewTangent;
            
            // Functions
            // Remap
            float remap(float iMin, float iMax, float oMin, float oMax, float inputValue) {
              float relativeInput = ( inputValue - iMin ) / ( iMax - iMin );
              float oInc = oMax - oMin;
              float oVal = oMin + (oInc * relativeInput);
              
              if (oVal > oMax)
                oVal = oMax;
              else if(oVal < oMin)
                oVal = oMin;
              
              return oVal;
            }

            // Comes out of Vertex Shader 
            struct VertexOutput
            {
                float4 vertex : SV_POSITION;
                float4 normal : NORMAL;
                float3 worldPos : TEXCOORD2;
            };
            


            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = v.normal;
                o.worldPos = mul( unity_ObjectToWorld, v.vertex );
                return o;
            }

            fixed4 frag (VertexOutput o) : SV_Target
            {
                float3 normal = float3(o.normal.xyz);
                float3 normalizedNormal = normalize(normal);
                float3 worldNormal =  mul( unity_ObjectToWorld, normal );
                worldNormal = normalize( worldNormal );
                
                
                // -------------------- Falloff Values
                float transGap = 0.01;                              
                
                // Cell Shading Diffuse Variables
                float FO_light_input_upperLim = 1;
                float FO_light_input_lowerLim = _LightLimit;
                float FO_light_output_upperLim = 1;
                float FO_light_output_lowerLim = FO_light_output_upperLim - _LightRange;
                
                float FO_light_trans_input_upperLim = FO_light_input_lowerLim;
                float FO_light_trans_input_lowerLim = FO_light_trans_input_upperLim - transGap;
                float FO_light_trans_output_upperLim = FO_light_output_lowerLim;
                float FO_light_trans_output_lowerLim = _PenumbraIntensity + _PenumbraRange;
                
                float FO_penumbra_input_upperLim = FO_light_trans_input_lowerLim;
                float FO_penumbra_input_lowerLim = _ShadowLimit;
                float FO_penumbra_output_upperLim = FO_light_trans_output_lowerLim;
                float FO_penumbra_output_lowerLim = _PenumbraIntensity;
                
                float FO_penumbra_trans_input_upperLim = FO_penumbra_input_lowerLim;
                float FO_penumbra_trans_input_lowerLim = FO_penumbra_trans_input_upperLim - transGap;
                float FO_penumbra_trans_output_upperLim = FO_penumbra_output_lowerLim;
                float FO_penumbra_trans_output_lowerLim = _ShadowIntensity + _PenumbraRange;
                
                float FO_shadow_input_upperLim = FO_penumbra_trans_input_lowerLim;
                float FO_shadow_input_lowerLim = -1;
                float FO_shadow_output_upperLim = FO_penumbra_trans_output_lowerLim;
                float FO_shadow_output_lowerLim = _ShadowIntensity;
                
                // Cell Shading Specular Variables
                float CS_Spec_shadow_input_lowerbound = 0;
                float CS_Spec_shadow_input_upperbound = 0.1;
                float CS_Spec_shadow_output_lowerbound = 0;
                float CS_Spec_shadow_output_upperbound = 0.1;
                
                float CS_Spec_penumbra_input_lowerbound = CS_Spec_shadow_input_upperbound;
                float CS_Spec_penumbra_input_upperbound = CS_Spec_penumbra_input_lowerbound + 0.05;
                float CS_Spec_penumbra_output_lowerbound = CS_Spec_shadow_output_upperbound;
                float CS_Spec_penumbra_output_upperbound = 0.8;
                
                float CS_Spec_light_input_lowerbound = CS_Spec_penumbra_input_upperbound;
                float CS_Spec_light_input_upperbound = 1.0;
                float CS_Spec_light_output_lowerbound = CS_Spec_penumbra_output_upperbound;
                float CS_Spec_light_output_upperbound = 1.0;
                
                // ---------------------------------------------
                float3 ambientLight = _AmbientLight;
                
                // ---------------- Diffuse

                // Light Position Data
                float3 lightPos = _WorldSpaceLightPos0.xyz;
                float3 localLightDir =  mul( unity_WorldToObject, lightPos);
                localLightDir = normalize(localLightDir);
                
                // Diffuse Light color and falloff
                float3 directLightColor = float3(_LightColor0.rgb);
                float rawDiffuseFalloff = dot(localLightDir, normalizedNormal);

                // Ambient Falloff
                float ambientFalloff = ( ambientLight.r + ambientLight.g + ambientLight.b ) / 3.0;
                
                // Composite Falloff
                float compositeFalloff = min(1 , ambientFalloff + rawDiffuseFalloff );
                                
                // Cellshaded Falloff
                float cellShadedFalloff = 1.0;
                
                if (compositeFalloff > FO_light_input_lowerLim) {
                  cellShadedFalloff = remap(FO_light_input_lowerLim, FO_light_input_upperLim, FO_light_output_lowerLim, FO_light_output_upperLim, compositeFalloff);
                }
                else if(compositeFalloff > FO_light_trans_input_lowerLim) {
                  cellShadedFalloff = remap(FO_light_trans_input_lowerLim, FO_light_trans_input_upperLim, FO_light_trans_output_lowerLim, FO_light_trans_output_upperLim, compositeFalloff);
                }
                else if(compositeFalloff > FO_penumbra_input_lowerLim) {
                  cellShadedFalloff = remap(FO_penumbra_input_lowerLim, FO_penumbra_input_upperLim, FO_penumbra_output_lowerLim, FO_penumbra_output_upperLim, compositeFalloff);
                }
                else if(compositeFalloff > FO_penumbra_trans_input_lowerLim) {
                  cellShadedFalloff = remap(FO_penumbra_trans_input_lowerLim, FO_penumbra_trans_input_upperLim, FO_penumbra_trans_output_lowerLim, FO_penumbra_trans_output_upperLim, compositeFalloff);
                }
                else {
                  cellShadedFalloff = remap(FO_shadow_input_lowerLim, FO_shadow_input_upperLim, FO_shadow_output_lowerLim, FO_shadow_output_upperLim, compositeFalloff);
                }
      
                float3 directDiffuse = directLightColor * cellShadedFalloff;
                
                // ---------------- Specular Base
                float3 camPos = _WorldSpaceCameraPos;
                float3 fragToCam = camPos - o.worldPos;
                float3 viewDir = normalize( fragToCam );
                float3 H = normalize(viewDir + lightPos);
                
                float specularFalloff = max( 0, dot( worldNormal , H) );
                
                // ---------------- Phong Specular
                float phongSpecularFalloff = pow(specularFalloff, _Specular);
                float3 phongDirectSpecular =  directLightColor * phongSpecularFalloff * _SpecularAlpha;
                
                // ---------------- Cell Specular

                float cellSpecularFalloff = pow(specularFalloff, _CellSpecular);
                
                // Cell Shading Specular Falloff
                if (cellSpecularFalloff < CS_Spec_shadow_input_upperbound) {
                  cellSpecularFalloff = remap(CS_Spec_shadow_input_lowerbound, CS_Spec_shadow_input_upperbound, CS_Spec_shadow_output_lowerbound, CS_Spec_shadow_output_upperbound, cellSpecularFalloff);
                } 
                else if (cellSpecularFalloff < CS_Spec_penumbra_input_upperbound) {
                  cellSpecularFalloff = remap(CS_Spec_penumbra_input_lowerbound, CS_Spec_penumbra_input_upperbound, CS_Spec_penumbra_output_lowerbound, CS_Spec_penumbra_output_upperbound, cellSpecularFalloff);
                }
                else {
                  cellSpecularFalloff = remap(CS_Spec_light_input_lowerbound, CS_Spec_light_input_upperbound, CS_Spec_light_output_lowerbound, CS_Spec_light_output_upperbound, cellSpecularFalloff);
                }
                
                float3 cellDirectSpecular =  directLightColor * cellSpecularFalloff * _CellSpecularAlpha;
                
                // ---------------- Normal to camera falloff Direction
                float cameraFalloff = 1.0;
                if (_DarkenViewTangent > 0) {
                  cameraFalloff = max( 0, dot( viewDir , worldNormal) );
                  cameraFalloff = 1- pow(1-cameraFalloff,2);
                  cameraFalloff = cameraFalloff * _DarkenViewTangent + ( 1 - _DarkenViewTangent);      
                  
                  float deniedRegion = 1;
                  deniedRegion = deniedRegion * ( 1 - cellSpecularFalloff ) ;
                  deniedRegion = deniedRegion * ( 1 - phongSpecularFalloff ) ;
                  
                  cameraFalloff = max( cameraFalloff , (1 - deniedRegion) );    
                }

                // ---------------- Composition
                
                // Light Composition
                float3 compositeLight = directDiffuse + ambientLight;
                compositeLight = saturate(compositeLight);
                
                // Surface Composition
                float3 surfaceColor = _ObjectColor * compositeLight;
                surfaceColor = surfaceColor + phongDirectSpecular + cellDirectSpecular;
                
                surfaceColor = surfaceColor * cameraFalloff;
                
                return float4(surfaceColor, 0);
            }
            ENDCG
        }
    }
}