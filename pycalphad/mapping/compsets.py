import numpy as np


class BinaryCompSet():
    def __init__(self, phase_name, temperature, indep_comp, composition, site_fracs):
        self.phase_name = phase_name
        self.temperature = temperature
        self.indep_comp = indep_comp
        self.composition = composition
        self.site_fracs = site_fracs

    def __repr__(self,):
        return "BinaryCompSet<{0}(T={1}, X({2})={3})>".format(self.phase_name, self.temperature, self.indep_comp, self.composition)

    def __str__(self,):
        return self.__repr__()

    @classmethod
    def from_dataset_vertex(cls, ds):
        def get_val(da):
            return da.values.flatten()[0]
        def get_vals(da):
            return da.values.flatten()
        indep_comp = [c for c in ds.coords if 'X_' in c][0][2:]

        return BinaryCompSet(get_val(ds.Phase),
                             get_val(ds.T),
                             indep_comp,
                             get_val(ds.X.sel(component=indep_comp)),
                             get_vals(ds.Y)
                            )

    def xdiscrepancy(self, other, ignore_phase=False):
        """
        Calculate the composition discrepancy (absolute difference) between this
        composition set and another.

        Parameters
        ----------
        other : BinaryCompSet
        ignore_phase : bool
            If False, unlike phases will give infinite discrepancy. If True, we
            only care about the composition and the real discrepancy will be returned.

        Returns
        -------
        np.float64

        """
        if not ignore_phase and self.phase_name != other.phase_name:
            return np.infty
        else:
            return np.abs(self.composition - other.composition)

    def ydiscrepancy(self, other):
        """
        Calculate the discrepancy (absolute differences) between the site
        fractions of this composition set and another as an array of discrepancies.

        Parameters
        ----------
        other : BinaryCompSet

        Returns
        -------
        Array of np.float64

        Notes
        -----
        The phases must match for this to be meaningful.

        """
        if self.phase_name != other.phase_name:
            return np.infty
        else:
            return np.abs(self.site_fracs - other.site_fracs)

    def ydiscrepancy_max(self, other):
        """
        Calculate the maximum discrepancy (absolute difference) between the site
        fractions of this composition set and another.

        Parameters
        ----------
        other : BinaryCompSet

        Returns
        -------
        np.float64

        Notes
        -----
        The phases must match for this to be meaningful.

        """
        if self.phase_name != other.phase_name:
            return np.infty
        else:
            return np.max(np.abs(self.site_fracs - other.site_fracs))


    def Tdiscrepancy(self, other, ignore_phase=False):
        """
        Calculate the temperature discrepancy (absolute difference) between this
        composition set and another.

        Parameters
        ----------
        other : BinaryCompSet
        ignore_phase : bool
            If False, unlike phases will give infinite discrepancy. If True, we
            only care about the composition and the real discrepancy will be returned.

        Returns
        -------
        np.float64

        """
        if not ignore_phase and self.phase_name != other.phase_name:
            return np.infty
        else:
            return np.abs(self.temperature - other.temperature)


    @staticmethod
    def mean_composition(compsets):
        """
        Return the mean composition of a list of composition sets.

        Parameters
        ----------
        compsets : list of composition sets

        Returns
        -------
        np.float

        """
        return np.mean([c.composition for c in compsets])