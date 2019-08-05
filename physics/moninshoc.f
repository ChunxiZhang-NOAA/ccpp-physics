!> \file moninshoc.f
!!  Contains most of the SHOC PBL/shallow convection scheme.

!> This module contains the CCPP-compliant SHOC scheme.
      module moninshoc

      contains

      subroutine moninshoc_init ()
      end subroutine moninshoc_init

      subroutine moninshoc_finalize ()
      end subroutine moninshoc_finalize

!!!!!  ==========================================================  !!!!!
! subroutine 'moninshoc' computes pbl height and applies vertical diffusion
! using the coefficient provided by the SHOC scheme (from previous step)
! 2015-05-04 - Shrinivas Moorthi - original version based on monin
! 2018-03-21 - Shrinivas Moorthi - fixed a bug related to tke vertical diffusion
!                                  and gneralized the tke location in tracer array
! 2018-03-23 - Shrinivas Moorthi - used twice the momentum diffusion coefficient
!                                  for tke as in Deardorff (1980) - added tridi1
!
!> \section arg_table_moninshoc_run Argument Table
!! | local_name     | standard_name                                                               | long_name                                             | units         | rank | type      |    kind   | intent | optional |
!! |----------------|-----------------------------------------------------------------------------|-------------------------------------------------------|---------------|------|-----------|-----------|--------|----------|
!! | ix             | horizontal_dimension                                                        | horizontal dimension                                  | count         |    0 | integer   |           | in     | F        |
!! | im             | horizontal_loop_extent                                                      | horizontal loop extent                                | count         |    0 | integer   |           | in     | F        |
!! | km             | vertical_dimension                                                          | vertical layer dimension                              | count         |    0 | integer   |           | in     | F        |
!! | ntrac          | number_of_vertical_diffusion_tracers                                        | number of tracers to diffuse vertically               | count         |    0 | integer   |           | in     | F        |
!! | ntcw           | index_for_liquid_cloud_condensate                                           | cloud condensate index in tracer array                | index         |    0 | integer   |           | in     | F        |
!! | ncnd           | number_of_tracers_for_cloud_condensate                                      | number of tracers for cloud condensate                | count         |    0 | integer   |           | in     | F        |
!! | dv             | tendency_of_y_wind_due_to_model_physics                                     | updated tendency of the y wind                        | m s-2         |    2 | real      | kind_phys | inout  | F        |
!! | du             | tendency_of_x_wind_due_to_model_physics                                     | updated tendency of the x wind                        | m s-2         |    2 | real      | kind_phys | inout  | F        |
!! | tau            | tendency_of_air_temperature_due_to_model_physics                            | updated tendency of the temperature                   | K s-1         |    2 | real      | kind_phys | inout  | F        |
!! | rtg            | tendency_of_vertically_diffused_tracer_concentration                        | updated tendency of the tracers due to vertical diffusion in PBL scheme | kg kg-1 s-1   |    3 | real      | kind_phys | inout  | F        |
!! | u1             | x_wind                                                                      | x component of layer wind                             | m s-1         |    2 | real      | kind_phys | in     | F        |
!! | v1             | y_wind                                                                      | y component of layer wind                             | m s-1         |    2 | real      | kind_phys | in     | F        |
!! | t1             | air_temperature                                                             | layer mean air temperature                            | K             |    2 | real      | kind_phys | in     | F        |
!! | q1             | vertically_diffused_tracer_concentration                                    | tracer concentration diffused by PBL scheme           | kg kg-1       |    3 | real      | kind_phys | in     | F        |
!! | tkh            | atmosphere_heat_diffusivity_from_shoc                                       | diffusivity for heat from the SHOC scheme             | m2 s-1        |    2 | real      | kind_phys | in     | F        |
!! | prnum          | prandtl_number                                                              | turbulent Prandtl number                              | none          |    2 | real      | kind_phys | inout  | F        |
!! | ntke           | index_for_turbulent_kinetic_energy_vertical_diffusion_tracer | index for turbulent kinetic energy in the vertically diffused tracer array | index   |    0 | integer   |           | in     | F        |
!! | psk            | dimensionless_exner_function_at_lowest_model_interface                      | dimensionless Exner function at the surface interface | none          |    1 | real      | kind_phys | in     | F        |
!! | rbsoil         | bulk_richardson_number_at_lowest_model_level                                | bulk Richardson number at the surface                 | none          |    1 | real      | kind_phys | in     | F        |
!! | zorl           | surface_roughness_length                                                    | surface roughness length in cm                        | cm            |    1 | real      | kind_phys | in     | F        |
!! | u10m           | x_wind_at_10m                                                               | x component of wind at 10 m                           | m s-1         |    1 | real      | kind_phys | in     | F        |
!! | v10m           | y_wind_at_10m                                                               | y component of wind at 10 m                           | m s-1         |    1 | real      | kind_phys | in     | F        |
!! | fm             | Monin_Obukhov_similarity_function_for_momentum                              | Monin-Obukhov similarity function for momentum        | none          |    1 | real      | kind_phys | in     | F        |
!! | fh             | Monin_Obukhov_similarity_function_for_heat                                  | Monin-Obukhov similarity function for heat            | none          |    1 | real      | kind_phys | in     | F        |
!! | tsea           | surface_skin_temperature                                                    | surface skin temperature                              | K             |    1 | real      | kind_phys | in     | F        |
!! | heat           | kinematic_surface_upward_sensible_heat_flux                                 | kinematic surface upward sensible heat flux           | K m s-1       |    1 | real      | kind_phys | in     | F        |
!! | evap           | kinematic_surface_upward_latent_heat_flux                                   | kinematic surface upward latent heat flux             | kg kg-1 m s-1 |    1 | real      | kind_phys | in     | F        |
!! | stress         | surface_wind_stress                                                         | surface wind stress                                   | m2 s-2        |    1 | real      | kind_phys | in     | F        |
!! | spd1           | wind_speed_at_lowest_model_layer                                            | wind speed at lowest model level                      | m s-1         |    1 | real      | kind_phys | in     | F        |
!! | kpbl           | vertical_index_at_top_of_atmosphere_boundary_layer                          | PBL top model level index                             | index         |    1 | integer   |           | out    | F        |
!! | prsi           | air_pressure_at_interface                                                   | air pressure at model layer interfaces                | Pa            |    2 | real      | kind_phys | in     | F        |
!! | del            | air_pressure_difference_between_midlayers                                   | pres(k) - pres(k+1)                                   | Pa            |    2 | real      | kind_phys | in     | F        |
!! | prsl           | air_pressure                                                                | mean layer pressure                                   | Pa            |    2 | real      | kind_phys | in     | F        |
!! | prslk          | dimensionless_exner_function_at_model_layers                                | Exner function at layers                              | none          |    2 | real      | kind_phys | in     | F        |
!! | phii           | geopotential_at_interface                                                   | geopotential at model layer interfaces                | m2 s-2        |    2 | real      | kind_phys | in     | F        |
!! | phil           | geopotential                                                                | geopotential at model layer centers                   | m2 s-2        |    2 | real      | kind_phys | in     | F        |
!! | delt           | time_step_for_physics                                                       | time step for physics                                 | s             |    0 | real      | kind_phys | in     | F        |
!! | dusfc          | instantaneous_surface_x_momentum_flux                                       | x momentum flux                                       | Pa            |    1 | real      | kind_phys | out    | F        |
!! | dvsfc          | instantaneous_surface_y_momentum_flux                                       | y momentum flux                                       | Pa            |    1 | real      | kind_phys | out    | F        |
!! | dtsfc          | instantaneous_surface_upward_sensible_heat_flux                             | surface upward sensible heat flux                     | W m-2         |    1 | real      | kind_phys | out    | F        |
!! | dqsfc          | instantaneous_surface_upward_latent_heat_flux                               | surface upward latent heat flux                       | W m-2         |    1 | real      | kind_phys | out    | F        |
!! | dkt            | atmosphere_heat_diffusivity                                                 | diffusivity for heat                                  | m2 s-1        |    2 | real      | kind_phys | out    | F        |
!! | hpbl           | atmosphere_boundary_layer_thickness                                         | PBL thickness                                         | m             |    1 | real      | kind_phys | out    | F        |
!! | kinver         | index_of_highest_temperature_inversion                                      | index of highest temperature inversion                | index         |    1 | integer   |           | in     | F        |
!! | xkzm_m         | atmosphere_momentum_diffusivity_background                                  | background value of momentum diffusivity              | m2 s-1        |    0 | real      | kind_phys | in     | F        |
!! | xkzm_h         | atmosphere_heat_diffusivity_background                                      | background value of heat diffusivity                  | m2 s-1        |    0 | real      | kind_phys | in     | F        |
!! | xkzm_s         | diffusivity_background_sigma_level                                          | sigma level threshold for background diffusivity      | none          |    0 | real      | kind_phys | in     | F        |
!! | xkzminv        | atmosphere_heat_diffusivity_background_maximum                              | max. background val. diffusivity in inversion layers  | m2 s-1        |    0 | real      | kind_phys | in     | F        |
!! | lprnt          | flag_print                                                                  | flag for printing diagnostics to output               | flag          |    0 | logical   |           | in     | F        |
!! | ipr            | horizontal_index_of_printed_column                                          | horizontal index of printed column                    | index         |    0 | integer   |           | in     | F        |
!! | me             | mpi_rank                                                                    | current MPI-rank                                      | index         |    0 | integer   |           | in     | F        |
!! | grav           | gravitational_acceleration                                                  | gravitational acceleration                            | m s-2         |    0 | real      | kind_phys | in     | F        |
!! | rd             | gas_constant_dry_air                                                        | ideal gas constant for dry air                        | J kg-1 K-1    |    0 | real      | kind_phys | in     | F        |
!! | cp             | specific_heat_of_dry_air_at_constant_pressure                               | specific heat of dry air at constant pressure         | J kg-1 K-1    |    0 | real      | kind_phys | in     | F        |
!! | hvap           | latent_heat_of_vaporization_of_water_at_0C                                  | latent heat of evaporation/sublimation                | J kg-1        |    0 | real      | kind_phys | in     | F        |
!! | fv             | ratio_of_vapor_to_dry_air_gas_constants_minus_one                           | (rv/rd) - 1 (rv = ideal gas constant for water vapor) | none          |    0 | real      | kind_phys | in     | F        |
!! | errmsg         | ccpp_error_message                                                          | error message for error handling in CCPP              | none          |    0 | character | len=*     | out    | F        |
!! | errflg         | ccpp_error_flag                                                             | error flag for error handling in CCPP                 | flag          |    0 | integer   |           | out    | F        |
!!
      subroutine moninshoc_run (ix,im,km,ntrac,ntcw,ncnd,dv,du,tau,rtg,
     &                     u1,v1,t1,q1,tkh,prnum,ntke,
     &                     psk,rbsoil,zorl,u10m,v10m,fm,fh,
     &                     tsea,heat,evap,stress,spd1,kpbl,
     &                     prsi,del,prsl,prslk,phii,phil,delt,
     &                     dusfc,dvsfc,dtsfc,dqsfc,dkt,hpbl,
     &                     kinver,xkzm_m,xkzm_h,xkzm_s,xkzminv,
     &                     lprnt,ipr,me,
     &                     grav, rd, cp, hvap, fv,
     &                     errmsg,errflg)
!
      use machine  , only : kind_phys
      use funcphys , only : fpvs

      implicit none
!
!     arguments
!
      logical,                                  intent(in) :: lprnt
      integer,                                  intent(in) :: ix, im,
     &  km, ntrac, ntcw, ncnd, ntke, ipr, me
      integer, dimension(im),                   intent(in) ::  kinver

      real(kind=kind_phys),                     intent(in) :: delt,
     &  xkzm_m, xkzm_h, xkzm_s, xkzminv
      real(kind=kind_phys),                     intent(in) :: grav,
     &  rd, cp, hvap, fv
      real(kind=kind_phys), dimension(im),      intent(in) :: psk,
     &  rbsoil, zorl, u10m, v10m, fm, fh, tsea, heat, evap, stress, spd1
      real(kind=kind_phys), dimension(ix,km),   intent(in) :: u1, v1,
     &  t1, tkh, del, prsl, phil, prslk
      real(kind=kind_phys), dimension(ix,km+1), intent(in) :: prsi, phii
      real(kind=kind_phys), dimension(ix,km,ntrac), intent(in) :: q1

      real(kind=kind_phys), dimension(im,km),   intent(inout) :: du, dv,
     &  tau, prnum
      real(kind=kind_phys), dimension(im,km,ntrac), intent(inout) :: rtg

      integer, dimension(im),                   intent(out) :: kpbl
      real(kind=kind_phys), dimension(im),      intent(out) :: dusfc,
     &  dvsfc, dtsfc, dqsfc, hpbl
      real(kind=kind_phys), dimension(im,km-1), intent(out) :: dkt

      character(len=*),                         intent(out) :: errmsg
      integer,                                  intent(out) :: errflg
!
!    locals
!
      integer i,is,k,kk,km1,kmpbl,kp1, ntloc
!
      logical  pblflg(im), sfcflg(im), flg(im)

      real(kind=kind_phys), dimension(im) ::  phih, phim
     &,                     rbdn, rbup, sflux, z0, crb, zol, thermal
     &,                     beta, tx1
!
      real(kind=kind_phys), dimension(im,km)  :: theta, thvx, zl, a1, ad
     &,                                          dt2odel
      real(kind=kind_phys), dimension(im,km-1):: xkzo, xkzmo, al, au
     &,                                          dku, rdzt
!
      real(kind=kind_phys) zi(im,km+1), a2(im,km*(ntrac+1))
!
      real(kind=kind_phys) dsdz2,  dsdzq,  dsdzt, dsig, dt2, rdt
     &,                    dtodsd, dtodsu, rdz,   tem,  tem1
     &,                    ttend,  utend, vtend,  qtend
     &,                    spdk2,  rbint, ri,     zol1, robn, bvf2
!
      real(kind=kind_phys), parameter ::  zolcr=0.2,
     &                      zolcru=-0.5,  rimin=-100.,    sfcfrac=0.1,
     &                      crbcon=0.25,  crbmin=0.15,    crbmax=0.35,
     &                      qmin=1.e-8,   zfmin=1.e-8,    qlmin=1.e-12,
     &                      aphi5=5.,     aphi16=16.,     f0=1.e-4
     &,                     dkmin=0.0,    dkmax=1000.
!    &,                     dkmin=0.0,    dkmax=1000.,    xkzminv=0.3
     &,                     prmin=0.25,     prmax=4.0
     &,                     vk=0.4, cfac=6.5
      real(kind=kind_phys) :: gravi, cont, conq, conw, gocp

      gravi = 1.0/grav
      cont = cp/grav
      conq = hvap/grav
      conw = 1.0/grav
      gocp = grav/cp

! Initialize CCPP error handling variables
      errmsg = ''
      errflg = 0
!
!-----------------------------------------------------------------------
!
!     compute preliminary variables
!
      if (ix < im) stop
!
!     if (lprnt) write(0,*)' in moninshoc tsea=',tsea(ipr)
      dt2   = delt
      rdt   = 1. / dt2
      km1   = km - 1
      kmpbl = km / 2
!
      do k=1,km
        do i=1,im
          zi(i,k)      = phii(i,k) * gravi
          zl(i,k)      = phil(i,k) * gravi
          dt2odel(i,k) = dt2 / del(i,k)
        enddo
      enddo
      do i=1,im
         zi(i,km+1) = phii(i,km+1) * gravi
      enddo
!
      do k = 1,km1
        do i=1,im
          rdzt(i,k)  = 1.0 / (zl(i,k+1) - zl(i,k))
          prnum(i,k) = 1.0
        enddo
      enddo
!               Setup backgrond diffision
      do i=1,im
        prnum(i,km) = 1.0
        tx1(i) = 1.0 / prsi(i,1)
      enddo
      do k = 1,km1
        do i=1,im
          xkzo(i,k)  = 0.0
          xkzmo(i,k) = 0.0
!         if (k < kinver(i)) then
          if (k <= kinver(i)) then
!    vertical background diffusivity for heat and momentum
            tem1       = 1.0 - prsi(i,k+1) * tx1(i)
            tem1       = min(1.0, exp(-tem1 * tem1 * 10.0))
            xkzo(i,k)  = xkzm_h * tem1
            xkzmo(i,k) = xkzm_m * tem1
          endif
        enddo
      enddo
!     if (lprnt) then
!       print *,' xkzo=',(xkzo(ipr,k),k=1,km1)
!       print *,' xkzmo=',(xkzmo(ipr,k),k=1,km1)
!     endif
!
!  diffusivity in the inversion layer is set to be xkzminv (m^2/s)
!
      do k = 1,kmpbl
        do i=1,im
          if(zi(i,k+1) > 250.) then
            tem1 = (t1(i,k+1)-t1(i,k)) * rdzt(i,k)
            if(tem1 > 1.e-5) then
               xkzo(i,k)  = min(xkzo(i,k),xkzminv)
            endif
          endif
        enddo
      enddo
!
!
      do i = 1,im
         z0(i)     = 0.01 * zorl(i)
         kpbl(i)   = 1
         hpbl(i)   = zi(i,1)
         pblflg(i) = .true.
         sfcflg(i) = .true.
         if(rbsoil(i) > 0.) sfcflg(i) = .false.
         dusfc(i)  = 0.
         dvsfc(i)  = 0.
         dtsfc(i)  = 0.
         dqsfc(i)  = 0.
      enddo
!
      do k = 1,km
        do i=1,im
          tx1(i) = 0.0
        enddo
        do kk=1,ncnd
          do i=1,im
            tx1(i) = tx1(i) + max(q1(i,k,ntcw+kk-1), qlmin)
          enddo
        enddo
        do i = 1,im
          theta(i,k) = t1(i,k) * psk(i) / prslk(i,k)
          thvx(i,k)  = theta(i,k)*(1.+fv*max(q1(i,k,1),qmin)-tx1(i))
        enddo
      enddo
!
!     if (lprnt) write(0,*)' heat=',heat(ipr),' evap=',evap(ipr)
      do i = 1,im
         sflux(i)  = heat(i) + evap(i)*fv*theta(i,1)
         if(.not.sfcflg(i) .or. sflux(i) <= 0.) pblflg(i)=.false.
         beta(i)  = dt2 / (zi(i,2)-zi(i,1))
      enddo
!
!  compute the pbl height
!
!     write(0,*)' IN moninbl u10=',u10m(1:5),' v10=',v10m(1:5)
      do i=1,im
         flg(i)  = .false.
         rbup(i) = rbsoil(i)
!
         if(pblflg(i)) then
           thermal(i) = thvx(i,1)
           crb(i) = crbcon
         else
           thermal(i) = tsea(i)*(1.+fv*max(q1(i,1,1),qmin))
           tem   = max(1.0, sqrt(u10m(i)*u10m(i) + v10m(i)*v10m(i)))
           robn   = tem / (f0 * z0(i))
           tem1   = 1.e-7 * robn
           crb(i) = max(min(0.16 * (tem1 ** (-0.18)), crbmax), crbmin)
         endif
      enddo
      do k = 1, kmpbl
        do i = 1, im
          if(.not.flg(i)) then
            rbdn(i) = rbup(i)
            spdk2   = max((u1(i,k)*u1(i,k)+v1(i,k)*v1(i,k)), 1.)
            rbup(i) = (thvx(i,k)-thermal(i))*phil(i,k)
     &              / (thvx(i,1)*spdk2)
            kpbl(i) = k
            flg(i)  = rbup(i) > crb(i)
          endif
        enddo
      enddo
      do i = 1,im
        if(kpbl(i) > 1) then
          k = kpbl(i)
          if(rbdn(i) >= crb(i)) then
            rbint = 0.
          elseif(rbup(i) <= crb(i)) then
            rbint = 1.
          else
            rbint = (crb(i)-rbdn(i)) / (rbup(i)-rbdn(i))
          endif
          hpbl(i) = zl(i,k-1) + rbint*(zl(i,k)-zl(i,k-1))
          if(hpbl(i) < zi(i,kpbl(i))) kpbl(i) = kpbl(i) - 1
        else
          hpbl(i) = zl(i,1)
          kpbl(i) = 1
        endif
      enddo
!
!  compute similarity parameters
!
      do i=1,im
         zol(i) = max(rbsoil(i)*fm(i)*fm(i)/fh(i),rimin)
         if(sfcflg(i)) then
           zol(i) = min(zol(i),-zfmin)
         else
           zol(i) = max(zol(i),zfmin)
         endif
         zol1 = zol(i)*sfcfrac*hpbl(i)/zl(i,1)
         if(sfcflg(i)) then
!          phim(i) = (1.-aphi16*zol1)**(-1./4.)
!          phih(i) = (1.-aphi16*zol1)**(-1./2.)
           tem     = 1.0 / max(1. - aphi16*zol1, 1.0e-8)
           phih(i) = sqrt(tem)
           phim(i) = sqrt(phih(i))
         else
           phim(i) = 1. + aphi5*zol1
           phih(i) = phim(i)
         endif
      enddo
!
!  enhance the pbl height by considering the thermal excess
!
      do i=1,im
         flg(i)  = .true.
         if (pblflg(i)) then
           flg(i) = .false.
           rbup(i) = rbsoil(i)
         endif
      enddo
      do k = 2, kmpbl
        do i = 1, im
          if(.not.flg(i)) then
            rbdn(i) = rbup(i)
            spdk2   = max((u1(i,k)*u1(i,k)+v1(i,k)*v1(i,k)), 1.)
            rbup(i) = (thvx(i,k)-thermal(i)) * phil(i,k)
     &              / (thvx(i,1)*spdk2)
            kpbl(i) = k
            flg(i)  = rbup(i) > crb(i)
          endif
        enddo
      enddo
      do i = 1,im
        if (pblflg(i)) then
          k = kpbl(i)
          if(rbdn(i) >= crb(i)) then
            rbint = 0.
          elseif(rbup(i) <= crb(i)) then
            rbint = 1.
          else
            rbint = (crb(i)-rbdn(i)) / (rbup(i)-rbdn(i))
          endif
          if (k > 1) then
            hpbl(i) = zl(i,k-1) + rbint*(zl(i,k)-zl(i,k-1))
            if(hpbl(i) < zi(i,kpbl(i))) kpbl(i) = kpbl(i) - 1
            if(kpbl(i) <= 1) then
              pblflg(i) = .false.
            endif
          else
            pblflg(i) = .false.
          endif
        endif
        if (pblflg(i)) then
          tem = phih(i)/phim(i) + cfac*vk*sfcfrac
        else
          tem = phih(i)/phim(i)
        endif
        prnum(i,1) = min(prmin,max(prmax,tem))
      enddo
!
      do i = 1, im
        if(zol(i) > zolcr) then
          kpbl(i) = 1
        endif
      enddo
!
!  compute Prandtl number above boundary layer
!
      do k = 1, km1
        kp1 = k + 1
        do i=1,im
          if(k >= kpbl(i)) then
            rdz  = rdzt(i,k)
            tem  = u1(i,k) - u1(i,kp1)
            tem1 = v1(i,k) - v1(i,kp1)
            tem  = (tem*tem + tem1*tem1) * rdz * rdz
            bvf2 = (0.5*grav)*(thvx(i,kp1)-thvx(i,k))*rdz
     &           / (t1(i,k)+t1(i,kp1))
            ri   = max(bvf2/tem,rimin)
            if(ri < 0.) then ! unstable regime
              prnum(i,kp1) = 1.0
            else
              prnum(i,kp1) = min(1.0 + 2.1*ri, prmax)
            endif
          elseif (k > 1) then
            prnum(i,kp1) = prnum(i,1)
          endif
!
!         prnum(i,kp1) = 1.0
          prnum(i,kp1) = max(prmin, min(prmax, prnum(i,kp1)))
          tem      = tkh(i,kp1) * prnum(i,kp1)
          dku(i,k) = max(min(tem+xkzmo(i,k),       dkmax), xkzmo(i,k))
          dkt(i,k) = max(min(tkh(i,kp1)+xkzo(i,k), dkmax), xkzo(i,k))
        enddo
      enddo
!
!     compute tridiagonal matrix elements for heat and moisture
!
      do i=1,im
         ad(i,1) = 1.
         a1(i,1) = t1(i,1)   + beta(i) * heat(i)
         a2(i,1) = q1(i,1,1) + beta(i) * evap(i)
      enddo
!     if (lprnt) write(0,*)' a1=',a1(ipr,1),' beta=',beta(ipr)
!    &,' heat=',heat(ipr), ' t1=',t1(ipr,1)

      ntloc = 1
      if(ntrac > 1) then
        is    = 0
        do k = 2, ntrac
          if (k /= ntke) then
            ntloc = ntloc + 1
            is = is + km
            do i = 1, im
              a2(i,1+is) = q1(i,1,k)
            enddo
          endif
        enddo
      endif
!
      do k = 1,km1
        kp1 = k + 1
        do i = 1,im
          dtodsd    = dt2odel(i,k)
          dtodsu    = dt2odel(i,kp1)
          dsig      = prsl(i,k)-prsl(i,kp1)
          rdz       = rdzt(i,k)
          tem1      = dsig * dkt(i,k) * rdz
          dsdz2     = tem1 * rdz
          au(i,k)   = -dtodsd*dsdz2
          al(i,k)   = -dtodsu*dsdz2
!
          ad(i,k)   = ad(i,k)-au(i,k)
          ad(i,kp1) = 1.-al(i,k)
          dsdzt     = tem1 * gocp
          a1(i,k)   = a1(i,k)   + dtodsd*dsdzt
          a1(i,kp1) = t1(i,kp1) - dtodsu*dsdzt
          a2(i,kp1) = q1(i,kp1,1)
!
        enddo
      enddo
!
      if(ntrac > 1) then
        is = 0
        do kk = 2, ntrac
          if (kk /= ntke) then
            is = is + km
            do k = 1, km1
              kp1 = k + 1
              do i = 1, im
                a2(i,kp1+is) = q1(i,kp1,kk)
              enddo
            enddo
          endif
        enddo
      endif
!
!     solve tridiagonal problem for heat and moisture
!
      call tridin(im,km,ntloc,al,ad,au,a1,a2,au,a1,a2)

!
!     recover tendencies of heat and moisture
!
      do  k = 1,km
         do i = 1,im
            ttend      = (a1(i,k)-t1(i,k))   * rdt
            qtend      = (a2(i,k)-q1(i,k,1)) * rdt
            tau(i,k)   = tau(i,k)   + ttend
            rtg(i,k,1) = rtg(i,k,1) + qtend
            dtsfc(i)   = dtsfc(i)   + cont*del(i,k)*ttend
            dqsfc(i)   = dqsfc(i)   + conq*del(i,k)*qtend
         enddo
      enddo
      if(ntrac > 1) then
        is = 0
        do kk = 2, ntrac
          if (kk /= ntke) then
            is = is + km
            do k = 1, km
              do i = 1, im
                qtend = (a2(i,k+is)-q1(i,k,kk))*rdt
                rtg(i,k,kk) = rtg(i,k,kk) + qtend
              enddo
            enddo
          endif
        enddo
      endif
!
!     compute tridiagonal matrix elements for momentum
!
      do i=1,im
         ad(i,1) = 1.0 + beta(i) * stress(i) / spd1(i)
         a1(i,1) = u1(i,1)
         a2(i,1) = v1(i,1)
      enddo
!
      do k = 1,km1
        kp1 = k + 1
        do i=1,im
          dtodsd    = dt2odel(i,k)
          dtodsu    = dt2odel(i,kp1)
          dsig      = prsl(i,k)-prsl(i,kp1)
          rdz       = rdzt(i,k)
          tem1      = dsig*dku(i,k)*rdz
          dsdz2     = tem1 * rdz
          au(i,k)   = -dtodsd*dsdz2
          al(i,k)   = -dtodsu*dsdz2
!
          ad(i,k)   = ad(i,k) - au(i,k)
          ad(i,kp1) = 1.0 - al(i,k)
          a1(i,kp1) = u1(i,kp1)
          a2(i,kp1) = v1(i,kp1)
!
        enddo
      enddo

      call tridi2(im,km,al,ad,au,a1,a2,au,a1,a2)
!
!     recover tendencies of momentum
!
      do k = 1,km
        do i = 1,im
          utend    = (a1(i,k)-u1(i,k))*rdt
          vtend    = (a2(i,k)-v1(i,k))*rdt
          du(i,k)  = du(i,k)  + utend
          dv(i,k)  = dv(i,k)  + vtend
          dusfc(i) = dusfc(i) + conw*del(i,k)*utend
          dvsfc(i) = dvsfc(i) + conw*del(i,k)*vtend
        enddo
      enddo
!
      if (ntke > 0) then    ! solve tridiagonal problem for momentum and tke
!
!     compute tridiagonal matrix elements for tke
!
        do i=1,im
           ad(i,1) = 1.0
           a1(i,1) = q1(i,1,ntke)
        enddo
!
        do k = 1,km1
          kp1 = k + 1
          do i=1,im
            dtodsd    = dt2odel(i,k)
            dtodsu    = dt2odel(i,kp1)
            dsig      = prsl(i,k)-prsl(i,kp1)
            rdz       = rdzt(i,k)
            tem1      = dsig*dku(i,k)*(rdz+rdz)
            dsdz2     = tem1 * rdz
            au(i,k)   = -dtodsd*dsdz2
            al(i,k)   = -dtodsu*dsdz2
!
            ad(i,k)   = ad(i,k) - au(i,k)
            ad(i,kp1) = 1.0 - al(i,k)
            a1(i,kp1) = q1(i,kp1,ntke)
          enddo
        enddo

        call tridi1(im,km,al,ad,au,a1,au,a1)
!
        do k = 1, km !     recover tendencies of tke
          do i = 1, im
            qtend = (a1(i,k)-q1(i,k,ntke))*rdt
            rtg(i,k,ntke) = rtg(i,k,ntke) + qtend
          enddo
        enddo
      endif
!
      return
      end subroutine moninshoc_run

      end module moninshoc
